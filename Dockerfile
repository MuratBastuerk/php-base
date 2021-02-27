FROM php:7.4.14-fpm-alpine3.12

ARG WITH_XDEBUG=true
ARG WITH_COMPOSER=true
ARG WITH_LUMENINSTALLER=true
ARG WITH_SWAGGERPHP=true
ARG WITH_OPCACHE=true
ARG APP_ENV=prod

# Für die Seite die betrieben wird
# selbst per openssl generieren
ADD dockerconf/cert/site.crt /etc/nginx/ssl/site.crt
ADD dockerconf/cert/site.key /etc/nginx/ssl/site.key

# nginx config
ADD dockerconf/conf/nginx.conf /etc/nginx/nginx.conf
ADD dockerconf/conf/site-ssl.conf /etc/nginx/conf.d/site-ssl.conf
# Linux System-Config
ADD dockerconf/conf/supervisord.conf /etc/supervisord.conf

# Wird bei Start des Containers ausgeführt
ADD dockerconf/scripts/docker-entrypoint.sh /docker-entrypoint.sh

# Configure nginx
RUN rm -fr /etc/nginx/conf.d/default.conf \
    && mkdir -p /run/nginx/

# Install and update dependencies
RUN apk update \
    && apk upgrade \
    && apk add --no-cache \
        nginx \
        supervisor \
        postgresql-dev \
        libpq \
        zip \
        libzip-dev \
        ca-certificates \
        bash \
        git \
    && update-ca-certificates \
    && docker-php-ext-install -j$(nproc) pgsql \
    && docker-php-ext-install -j$(nproc) pdo_pgsql \
    && docker-php-ext-install -j$(nproc) bcmath \
    && docker-php-ext-configure zip \
    && docker-php-ext-install zip

# Configure php
RUN set -eu; \
    mv /usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini; \
    { \
        echo '[global]'; \
        echo '; Maximum CloudWatch log event size is 256KB https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/cloudwatch_limits_cwl.html'; \
        echo 'log_limit = 65536'; \
        echo '[www]'; \
        echo 'listen = /var/run/php-fpm.sock'; \
        echo 'listen.mode = 0666'; \
    } | tee /usr/local/etc/php-fpm.d/zz-docker.conf; \
    { \
        echo 'error_reporting = E_ALL'; \
        echo 'display_startup_errors = On'; \
        echo 'display_errors = On'; \
        echo 'upload_max_filesize = 100M'; \
        echo 'post_max_size = 100M'; \
        echo '; Maximum CloudWatch log event size is 256KB https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/cloudwatch_limits_cwl.html'; \
        echo 'log_errors_max_len = 65536'; \
    } | tee -a /usr/local/etc/php/php.ini; \
    sed -i 's/expose_php\s*=.*/expose_php = Off/g' /usr/local/etc/php/php.ini;

# Install Xdebug extension
RUN if [ $WITH_XDEBUG = "true" ] ; then \
        set -eu; \
        apk add --no-cache $PHPIZE_DEPS; \
        pecl install xdebug-2.9.8; \
        docker-php-ext-enable xdebug; \
        { \
            echo 'xdebug.remote_enable=On'; \
            echo 'xdebug.remote_autostart=On'; \
            echo 'xdebug.remote_host=host.docker.internal'; \
        } | tee -a /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini; \
    fi;

# Install opcache
RUN set -eu; \
    if [ $WITH_OPCACHE = "true" ] ; then \
        [ "${APP_ENV}" = "prod" ] && OPCACHE_REVALIDATE_FREQ=86400 || OPCACHE_REVALIDATE_FREQ=0; \
        docker-php-ext-enable opcache; \
        { \
            echo 'opcache.enable=1'; \
            echo 'opcache.revalidate_freq=${OPCACHE_REVALIDATE_FREQ}'; \
            echo 'opcache.validate_timestamps=1'; \
            echo 'opcache.fast_shutdown=1'; \
            echo 'opcache.max_accelerated_files=10000'; \
            echo 'opcache.memory_consumption=192'; \
            echo 'opcache.max_wasted_percentage=10'; \
            echo 'opcache.interned_strings_buffer=16'; \
        } | tee -a /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini; \
    fi;

# Install composer
RUN if [ $WITH_COMPOSER = "true" ] || [ $WITH_SWAGGERPHP = "true" ] || [ $WITH_LUMENINSTALLER = "true" ] ; then \
        curl https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer ; \
    fi;

# Install swagger-php (depends on composer)
RUN if [ $WITH_SWAGGERPHP = "true" ] ; then \
        composer global require "zircote/swagger-php" ; \
    fi;

# Install lumen installer (depends on composer)
RUN if [ $WITH_LUMENINSTALLER = "true" ] ; then \
        composer global require "laravel/lumen-installer" ; \
    fi;

# Adopt path if composer apps are used
RUN if [ $WITH_SWAGGERPHP = "true" ] || [ $WITH_LUMENINSTALLER = "true" ] ; then \
        echo 'export PATH=$PATH:/root/.composer/vendor/bin' >> /etc/profile ; \
    fi;

ENV ENV="/etc/profile"

CMD ["sh", "-c", "/usr/bin/supervisord -n -c /etc/supervisord.conf"]
ENTRYPOINT [ "/docker-entrypoint.sh" ]