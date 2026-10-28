# syntax=docker/dockerfile:1

FROM composer:2 AS vendor

WORKDIR /app

COPY composer.json composer.lock symfony.lock ./
RUN composer install \
    --no-dev \
    --no-scripts \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader

COPY . .
RUN composer dump-autoload --optimize --classmap-authoritative --no-dev \
    && composer run-script --no-dev post-install-cmd || true


FROM php:8.3-fpm-bookworm AS app

RUN apt-get update && apt-get install -y --no-install-recommends \
        nginx \
        git \
        unzip \
        libpq-dev \
        librabbitmq-dev \
        libssl-dev \
        $PHPIZE_DEPS \
    && docker-php-ext-install -j$(nproc) pdo_pgsql opcache \
    && pecl install amqp \
    && docker-php-ext-enable amqp \
    && apt-get purge -y --auto-remove $PHPIZE_DEPS \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

COPY --from=vendor /app /var/www/html
COPY docker/nginx/default.conf /etc/nginx/sites-available/default
COPY docker/php/php.ini /usr/local/etc/php/conf.d/app.ini
COPY docker/app/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh \
    && rm -f /etc/nginx/sites-enabled/default \
    && ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default \
    && mkdir -p var/cache var/log var/share \
    && chown -R www-data:www-data /var/www/html \
    && chmod +x /usr/local/bin/entrypoint.sh bin/console

ENV APP_ENV=prod
ENV APP_DEBUG=0

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["app"]
