#!/bin/sh -l

set -x

cd "${GITHUB_WORKSPACE}"

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit 1

if "${INPUT_ENABLE_PHPSTAN}"; then
  echo 'Enabled PHPStan. Starting analyse...'
  phpstan ${INPUT_PHPSTAN_ARGS} \
    | reviewdog -f=phpstan \
      -name="PHPStan" \
      -reporter=${INPUT_REPORTER} \
      -filter-mode=${INPUT_FILTER_MODE} \
      -fail-on-error=${INPUT_FAIL_ON_ERROR} \
      -level="${INPUT_LEVEL}" \
      ${INPUT_REVIEWDOG_ARGS}
else
  echo 'Disabled PHPStan'
fi

if "${INPUT_ENABLE_PHPMD}"; then
  echo 'Enabled PHPMD. Starting analyse...'
  phpmd ${INPUT_PHPMD_ARGS} \
    | jq -r '.errors|to_entries[]|.value.fileName as $path|.value.message as $msg|"\($path):\($msg)"|match(", line: (\\d)").captures[].string as $line|match(", col: (\\d)").captures[].string as $col|"\($path):\($line):\($col):`Syntax error`<br>\($msg)"|gsub(", line:(.*)";"")' \
    | reviewdog -efm="%f:%l:%c:%m" \
      -name="PHPMD" \
      -reporter=${INPUT_REPORTER} \
      -filter-mode=${INPUT_FILTER_MODE} \
      -fail-on-error=${INPUT_FAIL_ON_ERROR} \
      -level="${INPUT_LEVEL}" \
      ${INPUT_REVIEWDOG_ARGS}
else
  echo 'Disabled PHPMD'
fi

if "${INPUT_ENABLE_PHPCS}"; then
  echo 'Enabled PHP_CodeSniffer. Starting analyse...'
  phpcs ${INPUT_PHPCS_ARGS} \
    | jq -r '.files|to_entries[]|.key as $path|.value.messages[] as $msg|"\($path):\($msg.line):\($msg.column):**\($msg.source)**\n`\($msg.message)`"' \
    | reviewdog -efm="%f:%l:%c:%m" \
      -name="PHP_CodeSniffer" \
      -reporter=${INPUT_REPORTER} \
      -filter-mode=${INPUT_FILTER_MODE} \
      -fail-on-error=${INPUT_FAIL_ON_ERROR} \
      -level="${INPUT_LEVEL}" \
      ${INPUT_REVIEWDOG_ARGS}
else
  echo 'Disabled PHP_CodeSniffer'
fi

if "${INPUT_ENABLE_PHPINDER}"; then
  echo 'Enabled Phinder. Starting analyse...'
  phinder ${INPUT_PHINDER_ARGS} \
    | jq -r '.result|to_entries[]|.value.path as $path|.value.location.start[0] as $line|.value.location.start[1] as $col|.value.rule as $rule|"\($path):\($line):\($col):`\($rule.id)`<br>\($rule.message)"' \
    | reviewdog -efm="%f:%l:%c:%m" \
      -name="Phinder" \
      -reporter=${INPUT_REPORTER} \
      -filter-mode=${INPUT_FILTER_MODE} \
      -fail-on-error=${INPUT_FAIL_ON_ERROR} \
      -level="${INPUT_LEVEL}" \
      ${INPUT_REVIEWDOG_ARGS}
else
  echo 'Disabled Phinder'
fi
