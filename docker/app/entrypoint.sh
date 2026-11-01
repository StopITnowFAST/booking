#!/bin/sh
set -e

cd /var/www/html

mkdir -p var/cache var/log var/share
chown -R www-data:www-data var || true

# Local override mounts php.dev.ini over zz-app.ini; if APP_ENV=dev and the
# disabled template exists without a mount, enable timestamp validation.
if [ "${APP_ENV:-prod}" = "dev" ] && [ -f /usr/local/etc/php/conf.d/zz-app.dev.ini.disabled ]; then
    if [ ! -f /usr/local/etc/php/conf.d/zz-app.ini ] || grep -q 'validate_timestamps = 0' /usr/local/etc/php/conf.d/zz-app.ini 2>/dev/null; then
        cp /usr/local/etc/php/conf.d/zz-app.dev.ini.disabled /usr/local/etc/php/conf.d/zz-app-dev.ini || true
    fi
fi

# When the project is bind-mounted, vendor from the image is hidden — install it.
if [ ! -f vendor/autoload.php ]; then
    echo "vendor/ missing — running composer install..."
    composer install --no-interaction --prefer-dist --ignore-platform-req=ext-amqp || \
        composer install --no-interaction --prefer-dist
fi

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
