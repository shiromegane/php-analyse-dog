#!/bin/sh -l
set -x

cd "${GITHUB_WORKSPACE}"
cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit 1

printf '\033[34m%s\033[m\n' "Working on $(pwd)"

if "${INPUT_DEBUG}"; then
  ls -la ./
fi

if "${INPUT_DEPENDENCY_UPDATE}" && [ -e composer.json ]; then
  printf '\033[33m%s\033[m\n' '"composer.json" is exist. Run install dependencies.'
  export COMPOSER_MEMORY_LIMIT=-1
  COMPOSER_MEMORY_LIMIT=-1 $(which composer) update
  COMPOSER_STATUS=$?
else
  if "${INPUT_DEPENDENCY_UPDATE}"; then
    printf '\033[33m%s\033[m\n' '"composer.json" is not exist.'
  else
    printf '\033[33m%s\033[m\n' '"dependency_update" is false.'
  fi
  COMPOSER_STATUS=0
fi

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

REVIEWDOG_OPTIONS="-reporter=${INPUT_REPORTER} -filter-mode=${INPUT_FILTER_MODE} -fail-on-error=${INPUT_FAIL_ON_ERROR} -level=${INPUT_LEVEL} ${INPUT_REVIEWDOG_ARGS}"

if "${INPUT_ENABLE_PHPSTAN}"; then
  printf '\033[33m%s\033[m\n' 'Starting analyse by "PHPStan"'
  phpstan ${INPUT_PHPSTAN_ARGS} | reviewdog -name='PHPStan' -f=phpstan ${REVIEWDOG_OPTIONS}
  PHPSTAN_STATUS=$?
  printf '\033[33m%s\033[m\n' 'Finished analyse by "PHPStan"'
else
  printf '\033[33m%s\033[m\n' 'Analyse by "PHPStan" is disabled'
  PHPSTAN_STATUS=0
fi

if "${INPUT_ENABLE_PHPMD}"; then
  printf '\033[33m%s\033[m\n' 'Starting analyse by "PHPMD"'
  phpmd ${INPUT_PHPMD_ARGS} \
    | jq -r '.errors|to_entries[]|.value.fileName as $path|.value.message as $msg|"\($path):\($msg)"|match(", line: (\\d)").captures[].string as $line|match(", col: (\\d)").captures[].string as $col|"\($path):\($line):\($col):`Syntax error`<br>\($msg)"|gsub(", line:(.*)";"")' \
    | reviewdog -name='PHPMD' -efm='%f:%l:%c:%m' ${REVIEWDOG_OPTIONS}
  PHPMD_STATUS=$?
  printf '\033[33m%s\033[m\n' 'Finished analyse by "PHPMD"'
else
  printf '\033[33m%s\033[m\n' 'Analyse by "PHPMD" is disabled'
  PHPMD_STATUS=0
fi

if "${INPUT_ENABLE_PHPCS}"; then
  printf '\033[33m%s\033[m\n' 'Starting analyse by "PHP_CodeSniffer"'
  phpcs ${INPUT_PHPCS_ARGS} \
    | jq -r '.files|to_entries[]|.key as $path|.value.messages[] as $msg|"\($path):\($msg.line):\($msg.column):`\($msg.source)`<br>\($msg.message)"' \
    | reviewdog -name='PHP_CodeSniffer' -efm='%f:%l:%c:%m' ${REVIEWDOG_OPTIONS}
  PHPCS_STATUS=$?
  printf '\033[33m%s\033[m\n' 'Finished analyse by "PHP_CodeSniffer"'
else
  printf '\033[33m%s\033[m\n' 'Analyse by "PHP_CodeSniffer" is disabled'
  PHPCS_STATUS=0
fi

if "${INPUT_ENABLE_PHINDER}"; then
  printf '\033[33m%s\033[m\n' 'Starting analyse by "Phinder"'
  phinder ${INPUT_PHINDER_ARGS} \
    | jq -r '.result|to_entries[]|.value.path as $path|.value.location.start[0] as $line|.value.location.start[1] as $col|.value.rule as $rule|"\($path):\($line):\($col):`\($rule.id)`<br>\($rule.message)"' \
    | reviewdog -name='Phinder' -efm='%f:%l:%c:%m' ${REVIEWDOG_OPTIONS}
  PHINDER_STATUS=$?
  printf '\033[33m%s\033[m\n' 'Finished analyse by "Phinder"'
else
  printf '\033[33m%s\033[m\n' 'Analyse by "Phinder" is disabled'
  PHINDER_STATUS=0
fi

if [ ${PHPSTAN_STATUS} -ne 0 ] || [ ${PHPMD_STATUS} -ne 0 ] || [ ${PHPCS_STATUS} -ne 0 ] || [ ${PHINDER_STATUS} -ne 0 ]; then
  printf '\033[31m%s\033[m\n' 'Some analysis is failing. Please fix the code.'
  exit 1
elif [ ${COMPOSER_STATUS} -ne 0 ]; then
  printf '\033[31m%s\033[m\n' 'Failed composer update.'
else
  printf '\033[32m%s\033[m\n' 'All analyzes completed successfully.'
  exit 0
fi
