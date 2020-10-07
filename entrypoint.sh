#!/bin/sh -l

if "${INPUT_DEBUG}"; then
  set -x
fi

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"
cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit 1

printf '\033[33m%s\033[m\n' "[PHP Analyse dog] Working on $(pwd)"

printStartMessage() {
  printf '\033[33m%s\033[m\n' "[$1] Start analyse."
}

printFinishedMessage() {
  printf '\033[33m%s\033[m\n' "[$1] Finished analyse."
}

printDisabledMessage() {
  printf '\033[33m%s\033[m\n' "[$1] Disabled analyse."
}

printDetectedMessage() {
  printf '\033[31m%s\033[m\n' "[$1] Detected some errors and warnings."
}

printSyntaxCheckMessage() {
  printf '\033[31m%s\033[m\n' "[$1] Cannot be executed unless the syntax check is passed."
}

printResultMessage() {
  if [ "$2" -ne 0 ]; then
    printDetectedMessage "$1"
  else
    printFinishedMessage "$1"
  fi
}

debugCat() {
  echo '[DEBUG]---------------------------------------------------------[START]'
  cat "$1"
  echo '[DEBUG]-----------------------------------------------------------[END]'
}

if "${INPUT_DEPENDENCY_UPDATE}" && [ -e composer.json ]; then
  printf '\033[33m%s\033[m\n' 'Update dependencies as "composer.json" exists.'
  COMPOSER_MEMORY_LIMIT=-1 $(which composer) update
  COMPOSER_STATUS=$?
else
  if "${INPUT_DEPENDENCY_UPDATE}"; then
    printf '\033[33m%s\033[m\n' 'Dependencies are not updated because "composer.json" does not exist.'
  else
    printf '\033[33m%s\033[m\n' 'Dependencies will not be updated as the "dependency_update" option is false.'
  fi
  COMPOSER_STATUS=0
fi

REVIEWDOG_OPTIONS="-reporter=${INPUT_REPORTER} -filter-mode=${INPUT_FILTER_MODE} -fail-on-error=${INPUT_FAIL_ON_ERROR} -level=${INPUT_LEVEL} ${INPUT_REVIEWDOG_ARGS}"

TOOL_NAME='PHP_CodeSniffer'
if "${INPUT_ENABLE_PHPCS}"; then
  printStartMessage ${TOOL_NAME}
  RESULT_FILE="${TOOL_NAME}_Results"

  phpcs ${INPUT_PHPCS_ARGS} \
    | jq -r '.files|to_entries[]|.key as $file|.value.messages[]|.line as $line|.column as $column|.source as $rule|.message as $message|"\($file):\($line):\($column):`\($rule)`<br>\($message)"' \
    > ${RESULT_FILE}

  if "${INPUT_DEBUG}"; then
    debugCat ${RESULT_FILE}
  fi

  cat < ${RESULT_FILE} | reviewdog -name="${TOOL_NAME}" -efm='%f:%l:%c:%m' ${REVIEWDOG_OPTIONS}
  PHPCS_STATUS=$?
  printResultMessage ${TOOL_NAME} ${PHPCS_STATUS}
else
  PHPCS_STATUS=0
  printDisabledMessage ${TOOL_NAME}
fi

TOOL_NAME='PHPMD'
if "${INPUT_ENABLE_PHPMD}"; then
  printStartMessage ${TOOL_NAME}
  RESULT_FILE="${TOOL_NAME}_Results"

  if [ ${PHPCS_STATUS} -eq 0 ]; then
    phpmd ${INPUT_PHPMD_ARGS} \
      | jq -r '.files[]|.file as $file|.violations[]|.description as $message|.rule as $rule|.beginLine as $line|"\($file):\($line):`\($rule)`<br>\($message)"' \
      > ${RESULT_FILE}

    if "${INPUT_DEBUG}"; then
      debugCat ${RESULT_FILE}
    fi

    cat < ${RESULT_FILE} | reviewdog -name="${TOOL_NAME}" -efm='%f:%l:%m' ${REVIEWDOG_OPTIONS}
    PHPMD_STATUS=$?
    printResultMessage ${TOOL_NAME} ${PHPMD_STATUS}
  else
    printSyntaxCheckMessage ${TOOL_NAME}
    PHPMD_STATUS=0
  fi
else
  PHPMD_STATUS=0
  printDisabledMessage ${TOOL_NAME}
fi

TOOL_NAME='Phinder'
if "${INPUT_ENABLE_PHINDER}"; then
  RESULT_FILE="${TOOL_NAME}_Results"
  printStartMessage ${TOOL_NAME}

  if [ ${PHPCS_STATUS} -eq 0 ] && [ ${PHPMD_STATUS} -eq 0 ]; then

    phinder ${INPUT_PHINDER_ARGS} \
      | jq -r '.result[]|.path as $file|.location.start[0] as $line|.location.start[1] as $column|.rule.id as $rule|.rule.message as $message|"\($file):\($line):\($column):`\($rule)`<br>\($message)"' \
      > ${RESULT_FILE}

    if "${INPUT_DEBUG}"; then
      debugCat ${RESULT_FILE}
    fi

    cat < ${RESULT_FILE} | reviewdog -name="${TOOL_NAME}" -efm='%f:%l:%c:%m' ${REVIEWDOG_OPTIONS}
    PHINDER_STATUS=$?
    printResultMessage ${TOOL_NAME} ${PHINDER_STATUS}
  else
    PHINDER_STATUS=0
    printSyntaxCheckMessage ${TOOL_NAME}
  fi
else
  PHINDER_STATUS=0
  printDisabledMessage ${TOOL_NAME}
fi

if [ ${COMPOSER_STATUS} -ne 0 ]; then
  printf '\033[31m%s\033[m\n' 'Failed composer update.'
  exit 1
elif [ ${PHPCS_STATUS} -ne 0 ] || [ ${PHPMD_STATUS} -ne 0 ] || [ ${PHINDER_STATUS} -ne 0 ]; then
  printf '\033[31m%s\033[m\n' 'Failed any analyse. Please fix the code.'
  exit 1
else
  printf '\033[32m%s\033[m\n' 'Successful all analyse.'
  exit 0
fi
