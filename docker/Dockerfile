FROM php:8.2-apache

ARG MOODLE_VERSION=v5.1.3

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl unzip libzip-dev libicu-dev libxml2-dev libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libpq-dev libonig-dev libcurl4-openssl-dev libssl-dev default-mysql-client postgresql-client ca-certificates \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" gd intl zip mysqli pdo pdo_mysql pdo_pgsql soap opcache \
    && rm -rf /var/lib/apt/lists/*

RUN a2enmod rewrite headers expires

WORKDIR /var/www/html

RUN git clone --branch ${MOODLE_VERSION} --depth 1 https://github.com/moodle/moodle.git /var/www/html \
    && chown -R www-data:www-data /var/www/html

ENV APACHE_DOCUMENT_ROOT=/var/www/html

RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf \
    && sed -ri -e 's!^\s*Listen\s+80\s*$!Listen 8080!g' /etc/apache2/ports.conf \
    && sed -ri -e 's!<VirtualHost \*:80>!<VirtualHost *:8080>!g' /etc/apache2/sites-available/*.conf /etc/apache2/sites-enabled/*.conf \
    && printf 'ServerName localhost\n' > /etc/apache2/conf-available/servername.conf \
    && a2enconf servername

USER 33:33

EXPOSE 8080
