FROM php:8.3-fpm-alpine

RUN set -eux; \
    apk add --no-cache libpq oniguruma; \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS postgresql-dev oniguruma-dev; \
    docker-php-ext-install -j"$(nproc)" \
        pdo_mysql pdo_pgsql mysqli mbstring; \
    apk del .build-deps

WORKDIR /var/www/html
EXPOSE 9000
CMD ["php-fpm"]
