FROM php:7.2.11-fpm-alpine3.8

RUN apk add --no-cache --virtual .persistent-deps \
    geoip \
    yarn \
    freetype \
    tzdata

RUN set -xe \
	&& apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
        freetype-dev \
        geoip-dev \
 #       openssl-dev \
        postgresql-dev \
        libpng \
        libpng-dev \
        libjpeg-turbo \
        libjpeg-turbo-dev

RUN set -xe \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer \
    && apk add --no-cache -u python py-pip \
    && pip install supervisor==3.3.1

# Install required PHP extensions
RUN set -xe \
    && docker-php-ext-install bcmath \
    && docker-php-ext-configure gd \
        --with-freetype-dir=/usr/lib/ \
        --with-png-dir=/usr/lib/ \
        --with-jpeg-dir=/usr/lib/ \
        --with-gd \
    && docker-php-ext-install pgsql pdo_pgsql gd  \
    && echo 'no' | pecl install redis  \
    && pecl install geoip-1.1.1

RUN  set -xe \
    && echo 'extension=geoip.so'     > $PHP_INI_DIR/conf.d/geoip.ini \
    && echo 'extension=redis.so'     > $PHP_INI_DIR/conf.d/redis.ini

COPY ./php.ini $PHP_INI_DIR/
COPY ./php-fpm/www.conf $PHP_INI_DIR/php-fpm.d/

# Add a cron entry for Laravel's command scheduler
RUN set -ex \
    && crontab -l | { cat; echo "* * * * * php /var/www/html/artisan schedule:run 2>&1 | /usr/bin/logger -t laravel_scheduler"; } | crontab -

COPY ./supervisord.conf /etc/supervisord.conf
COPY ./entrypoint.sh /

# Set the container entrypoint
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]

WORKDIR /var/www/html

RUN set -xe \
    && cd /var/www/html \
    && mkdir -p storage/framework/cache \
    && mkdir -p storage/framework/sessions \
    && mkdir -p storage/framework/views \
    && mkdir -p storage/logs

VOLUME /var/www