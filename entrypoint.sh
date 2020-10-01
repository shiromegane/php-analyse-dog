#!/bin/sh -l

#set -xe

#phplint .
#phpcs .
#/root/.composer/vendor/bin/phplint ${INPUT_PATH} ${INPUT_OPTIONS}

if [ ${INPUT_ENABLE_PHPCS} ]; then
  phpcs --report=json -q ${INPUT_PHPCS_OPTIONS} \
    | jq -r ' .files | to_entries[] | .key as $path | .value.messages[] as $msg | "\($path):\($msg.line):\($msg.column):`\($msg.source)`<br>\($msg.message)" ' \
    | reviewdog -efm="%f:%l:%c:%m" \
      -name="PHP_CodeSniffer" \
      -reporter="${INPUT_REPORTER}" \
      -filter-mode="${INPUT_FILTER_MODE}" \
      -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
      -level="${INPUT_LEVEL}" \
      ${INPUT_REVIEWDOG_OPTIONS}
else
  echo 'Disabled PHPCS'
fi

#if [ $phpcs_status = 1 ]; then
#  echo 'Errors found, but none of them can be fixed by PHPCBF.'
#elif [ $phpcs_status = 2 ]; then
#  echo 'Errors found, and some can be fixed by PHPCBF.'
#else
#  echo 'No errors found.'
#fi

/bin/sh
