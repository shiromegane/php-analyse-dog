ARG COMPOSER_VERSION=latest
ARG PHP_VERSION=7.4
ARG REVIEWDOG_VERSION=latest

FROM composer:${COMPOSER_VERSION} AS build
RUN composer global require squizlabs/php_codesniffer phpmd/phpmd sider/phinder

FROM php:${PHP_VERSION}-cli-alpine
COPY --from=build /tmp/vendor /root/.composer/vendor
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
RUN cp /usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN wget -O - -q https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b /usr/local/bin/ ${REVIEWDOG_VERSION}
RUN apk --no-cache add jq git
RUN ln -s /root/.composer/vendor/bin/phpmd /usr/local/bin/phpmd
RUN ln -s /root/.composer/vendor/bin/phpcs /usr/local/bin/phpcs
RUN ln -s /root/.composer/vendor/bin/phpcbf /usr/local/bin/phpcbf
RUN ln -s /root/.composer/vendor/bin/phinder /usr/local/bin/phinder

ENTRYPOINT ["/entrypoint.sh"]
