# 1C-Bitrix CMS Docker Environment

Универсальный Docker-окружение для разработки и деплоя сайтов на базе 1C-Bitrix CMS.

## Быстрый старт

```bash
# 1. Скопируйте шаблоны конфигурационных файлов
cp .env.example .env
cp nginx/nginx.conf.example nginx/nginx.conf
cp nginx/bitrix.conf.example nginx/bitrix.conf
cp php/php.ini.example php/php.ini
cp php/opcache.ini.example php/opcache.ini
cp mysql/conf.d/bitrix.cnf.example mysql/conf.d/bitrix.cnf

# 2. Отредактируйте конфигурацию под свой проект
nano .env                                    # пароли, имя БД
nano nginx/bitrix.conf                       # root — путь к проекту в www/

# 3. Соберите и запустите
docker compose build
docker compose up -d

# 4. Проверьте статус
docker compose ps
```

После запуска сайт будет доступен на `http://localhost`.

Файлы Bitrix размещаются в папке `www/` (каждый проект — отдельная подпапка).

### Выбор проекта

Проект выбирается директивой `root` в `nginx/bitrix.conf`:

```nginx
root /var/www/myproject.ru;
```

Для смены проекта достаточно изменить эту строку и перезапустить nginx:

```bash
docker compose restart nginx
```

## Структура проекта

```
.
├── Dockerfile              # PHP-FPM образ для 1C-Bitrix
├── docker-compose.yml      # Оркестрация всех сервисов
├── .dockerignore           # Исключения из контекста сборки
├── .env.example            # Шаблон переменных окружения
├── nginx/
│   ├── nginx.conf.example  # Шаблон основного конфига nginx
│   └── bitrix.conf.example # Шаблон виртуального хоста для Bitrix
├── php/
│   ├── php.ini.example     # Шаблон настроек PHP
│   └── opcache.ini.example # Шаблон настроек OPcache
├── mysql/
│   └── conf.d/
│       └── bitrix.cnf.example # Шаблон настроек MySQL/Percona
├── www/                    # Документ-корень (git-репозитории с Bitrix)
└── certs/                  # SSL-сертификаты (fullchain.pem, privkey.pem)
```

> **Примечание:** Конфигурационные файлы (`.conf`, `.ini`, `.cnf`) не хранятся в git.
> При первом запуске скопируйте шаблоны (`.example`) в рабочие файлы.

## Сервисы

| Сервис | Образ | Порт | Описание |
|--------|-------|------|----------|
| `nginx` | `nginx:stable-alpine` | 80, 443 | Веб-сервер, раздача статики, проксирование на PHP |
| `php` | Сборка из Dockerfile | 9000 (внутр.) | PHP-FPM с расширениями для Bitrix |
| `mysql` | `percona/percona-server:8.0` | 3306 (внутр.) | СУБД для хранения данных Bitrix |
| `memcached` | `memcached:alpine` | 11211 (внутр.) | Кэш данных (2048 МБ) |
| `memcached-sessions` | `memcached:alpine` | 11211 (внутр.) | Хранение PHP-сессий (128 МБ) |

## Конфигурация

### Переменные окружения (.env)

| Переменная | По умолчанию | Описание |
|------------|-------------|----------|
| `MYSQL_ROOT_PASSWORD` | `rootpassword` | Пароль root-пользователя MySQL |
| `MYSQL_DATABASE` | `bitrix` | Имя базы данных |
| `MYSQL_USER` | `bitrix` | Имя пользователя MySQL |
| `MYSQL_PASSWORD` | `bitrixpassword` | Пароль пользователя MySQL |

### Смена версии PHP

В `Dockerfile` и `docker-compose.yml` версия PHP задаётся через аргумент сборки:

```bash
# Собрать с PHP 8.4
docker compose build --build-arg PHP_VERSION=8.4

# Или изменить в docker-compose.yml永久но
# args:
#   PHP_VERSION: "8.4"
```

Поддерживаемые версии: `8.2`, `8.3`, `8.4` (и любые другие доступные в официальном образе `php`).

### Часовой пояс

В `Dockerfile` по умолчанию установлен `Europe/Moscow`. Измените через переменную `TZ` в `docker-compose.yml`:

```yaml
environment:
  TZ: Europe/Samara
```

## Управление

### Основные команды

```bash
# Запуск всех сервисов
docker compose up -d

# Остановка
docker compose down

# Перезапуск (с пересборкой образов)
docker compose up -d --build

# Просмотр логов
docker compose logs -f
docker compose logs -f php
docker compose logs -f nginx

# Статус сервисов
docker compose ps
```

### Подключение к контейнерам

```bash
# Shell в контейнере PHP
docker compose exec php bash

# Shell в контейнере MySQL
docker compose exec mysql mysql -u bitrix -p

# Выполнение команды в PHP
docker compose exec php php -v
docker compose exec php php -m
```

### База данных

```bash
# Экспорт
docker compose exec mysql mysqldump -u root -p bitrix > backup.sql

# Импорт
docker compose exec -T mysql mysql -u root -p bitrix < backup.sql

# Подключение
docker compose exec mysql mysql -u bitrix -p bitrix
```

### Кэш

```bash
# Очистка кэша Memcached
docker compose exec memcached echo "flush_all" | nc localhost 11211

# Очистка кэша сессий
docker compose exec memcached-sessions echo "flush_all" | nc localhost 11211
```

## PHP-расширения

### Установленные по умолчанию

**Core:**
`mbstring`, `gd`, `xml`, `curl`, `zip`, `intl`, `bcmath`, `soap`, `sockets`, `exif`, `sodium`, `opcache`, `pdo_mysql`, `mysqli`, `xsl`, `bz2`, `pcntl`

**Дополнительные:**
`imagick`, `redis`, `memcached`, `apcu`, `igbinary`, `msgpack`

### Добавление своих расширений

Отредактируйте `Dockerfile` и добавьте нужные расширения:

```dockerfile
# Установка через docker-php-ext-install
RUN docker-php-ext-install -j$(nproc) \
        ftp \
        imap \
        ldap

# Установка через PECL
RUN pecl install ssh2-1.3.1 \
    && docker-php-ext-enable ssh2
```

### Полный список доступных расширений

```bash
# Посмотреть доступные для установки
docker compose exec php apt-cache search php | grep extension

# Посмотреть установленные
docker compose exec php php -m
```

## SSL/HTTPS

1. Положите сертификаты в папку `certs/`:
   ```
   certs/
   ├── fullchain.pem
   └── privkey.pem
   ```

2. Раскомментируйте HTTPS-блок в `nginx/bitrix.conf`:
   ```nginx
   server {
       listen 443 ssl http2;
       server_name yourdomain.com;
       ssl_certificate /etc/nginx/certs/fullchain.pem;
       ssl_certificate_key /etc/nginx/certs/privkey.pem;
       # ... остальные настройки
   }
   ```

3. Перезапустите nginx:
   ```bash
   docker compose restart nginx
   ```

Для тестирования можно сгенерировать самоподписанный сертификат:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout certs/privkey.pem \
    -out certs/fullchain.pem
```

## Безопасность

### Что реализовано

- **Невидимый пользователь** — PHP-FPM работает от имени `appuser` (UID 1000), не от root
- **Блокировка опасных функций** — `exec`, `shell_exec`, `system`, `passthru`, `proc_open`, `popen`
- **Защита директорий** — запрет доступа к `/bitrix/modules`, `/bitrix/php_interface`, `/.git`, `/.env`
- **Security-заголовки** — `X-Frame-Options`, `X-Content-Type-Options`, `X-XSS-Protection`, `Referrer-Policy`
- **Rate limiting** — ограничение частоты запросов к AJAX-эндпоинтам
- **OPcache** — `validate_timestamps=0` (контейнер неизменяем, файлы не проверяются)
- **Сессии** — `httponly`, `samesite=Lax`, `strict_mode=1`, хранение в Memcached
- **Серверные токены** — `server_tokens off` (версия nginx скрыта)
- **PHP скрыт** — `expose_php = Off`
- **SSL** — поддержка TLS 1.2/1.3, HSTS-заголовки

### Рекомендации для продакшена

1. Смените все пароли в `.env` на уникальные
2. Включите SSL и настройте редирект HTTP → HTTPS
3. Настройте `opcache.validate_timestamps=0` (уже включено по умолчанию)
4. Ограничьте доступ к серверу через firewall
5. Настройте регулярные бэкапы MySQL
6. Мониторьте логи: `docker compose logs -f --tail=100`

## Решение проблем

### Сайт не открывается

```bash
# Проверьте статус сервисов
docker compose ps

# Проверьте логи
docker compose logs nginx
docker compose logs php
```

### Ошибка 502 Bad Gateway

PHP-FPM недоступен. Проверьте, запущен ли контейнер `php`:

```bash
docker compose ps php
docker compose logs php
```

### Ошибка подключения к MySQL

```bash
# Проверьте, готов ли MySQL
docker compose logs mysql | grep "ready for connections"

# Подождите 30-60 секунд после первого запуска
```

### Медленная работа

1. Увеличьте `memory_limit` в `php/php.ini`
2. Увеличьте `innodb_buffer_pool_size` в `mysql/conf.d/bitrix.cnf`
3. Проверьте, включён ли OPcache: `docker compose exec php php -i | grep opcache`

### Нехватка прав на файлы

```bash
# Исправьте права на директорию www
docker compose exec php chown -R appuser:appuser /var/www/html
```

### Ошибка "No such file or directory" при сборке

Убедитесь, что Docker установлен и запущен:

```bash
docker --version
docker compose version
```

## Полезные ссылки

- [Требования 1C-Bitrix](https://www.1c-bitrix.ru/products/cms/requirements.php)
- [Docker PHP образы](https://hub.docker.com/_/php)
- [Percona Server for MySQL](https://www.percona.com/software/mysql-database/percona-server)
- [Nginx документация](https://nginx.org/ru/docs/)
- [Bitrix Docker (официальный)](https://github.com/bitrix-tools/env-docker)
