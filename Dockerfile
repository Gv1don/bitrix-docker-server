ARG PHP_VERSION=8.3

FROM php:${PHP_VERSION}-fpm-bookworm

ARG HOST_UID=1000
ARG HOST_GID=1000

LABEL maintainer="1C-Bitrix Docker Image" \
      description="Minimal PHP-FPM image for 1C-Bitrix CMS"

ENV TZ=Europe/Moscow \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        unzip \
        libpng-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
        libzip-dev \
        libicu-dev \
        libmagickwand-dev \
        libxml2-dev \
        libxslt1-dev \
        libpq-dev \
        libmemcached-dev \
        libssl-dev \
        libldap2-dev \
        libsodium-dev \
        libcurl4-openssl-dev \
        libonig-dev \
        libbz2-dev \
        libexif-dev \
        libpspell-dev \
        libtidy-dev \
        libwebp-dev \
        librabbitmq-dev \
        pkg-config \
        imagemagick \
        ghostscript \
        poppler-utils \
        catdoc \
        git \
        tini \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    && docker-php-ext-install -j$(nproc) \
        mbstring \
        gd \
        xml \
        curl \
        zip \
        intl \
        bcmath \
        soap \
        sockets \
        exif \
        sodium \
        opcache \
        pdo_mysql \
        mysqli \
        xsl \
        bz2 \
        pcntl

RUN pecl install imagick redis memcached apcu igbinary msgpack \
    && docker-php-ext-enable \
        imagick \
        redis \
        memcached \
        apcu \
        igbinary \
        msgpack

RUN apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
        $buildDeps \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g ${HOST_GID} appuser \
    && useradd -u ${HOST_UID} -g appuser -m -s /bin/bash appuser

COPY php/php.ini /usr/local/etc/php/conf.d/zz-bitrix.ini
COPY php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

RUN mkdir -p /var/www \
    && chown -R appuser:appuser /var/www \
    && chown -R appuser:appuser /usr/local/etc/php/ \
    && find /usr/local/etc/php/conf.d/ -type d -exec chmod 755 {} + \
    && find /usr/local/etc/php/conf.d/ -type f -exec chmod 644 {} + \
    && mkdir -p /var/run/php \
    && chown appuser:appuser /var/run/php \
    && mkdir -p /tmp/bitrix_cache \
    && chown appuser:appuser /tmp/bitrix_cache \
    && rm -rf /var/log/*

RUN find /usr/local/bin/docker-php* -type f -exec strip --strip-unneeded {} + 2>/dev/null || true

USER appuser

WORKDIR /var/www

EXPOSE 9000

ENTRYPOINT ["tini", "--"]

CMD ["php-fpm"]
