# PHP Analyse dog

## Description
Run PHP code analyse on pull request and review comment via reviewdog.

## Inputs
name | description | required | default
---|---|---|---
github_token|GITHUB_TOKEN|true|-
level|Report level for reviewdog [info, warning, error]|false|'error'
reporter|Reporter of the rebiewdog command [github-pr-check, github-pr-review]|false|'github-pr-review'
filter_mode|Filtering mode for the reviewdog command [added, diff_context, file, nofilter]|false|'added'
fail_on_error|Exit code for reviewdog when errors are found [true, false]|false|'true'
reviewdog_args|Additional reviewdog options|false|''
enable_phpstan|Enable PHPStan [true, false]|false|true
enable_phpmd|Enable PHPMD [true, false]|false|false
enable_phpcs|Enable PHP_CodeSniffer [true, false]|false|true
enable_phinder|Enable Phinder [true, false]|false|false
phpstan_args|PHPStan command args|false|'analyse . --error-format=checkstyle --no-progress'
phpmd_args|PHPMD command args|false|'. json cleancode,codesize,controversial,design,naming,unusedcode'
phpcs_args|PHP_CodeSniffer command args|false|'. --report=json -q'
phinder_args|Phinder command args|false|'find -f "json" .'
workdir|The directory from which to look for and run commands|false|'.'
dependency_update|Update dependencies if you have "composer.json" in workdir|false|true

## Usage on Github Actions
```
uses: shiromegane/php-analyse-dog@v0.1.2
with:
  github_token: ${{ secrets.GITHUB_TOKEN }}
```
