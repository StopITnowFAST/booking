#!/bin/sh
set -e

cd /var/www/html

mkdir -p var/cache var/log var/share
chown -R www-data:www-data var || true

if [ "$1" = "app" ]; then
    php bin/console cache:clear --env="${APP_ENV:-prod}" --no-warmup 2>/dev/null || true
    php bin/console cache:warmup --env="${APP_ENV:-prod}" || true

    php-fpm -D
    exec nginx -g 'daemon off;'
fi

if [ "$1" = "worker" ]; then
    php bin/console cache:warmup --env="${APP_ENV:-prod}" || true
    exec php bin/console messenger:consume async -vv --time-limit=3600 --memory-limit=128M
fi

exec "$@"
