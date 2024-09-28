#!/bin/bash

# Функция отображения справки
usage() {
    echo "Использование: $0 --port PORT --mount MOUNT_POINT [опции]"
    echo "Опции:"
    echo "  --port            Порт для PostgreSQL (обязательный)"
    echo "  --mount           Точка монтирования для данных (обязательный)"
    echo "  --user            Имя пользователя PostgreSQL (по умолчанию: admin)"
    echo "  --password        Пароль пользователя PostgreSQL (по умолчанию: adminpass)"
    echo "  --dbname          Имя базы данных PostgreSQL (по умолчанию: testdb)"
    echo "  --dump            Путь к .backup файлу для восстановления"
    echo "  --help            Показать эту справку и выйти"
}

# Значения по умолчанию
POSTGRES_USER="admin"
POSTGRES_PASSWORD="adminpass"
POSTGRES_DB="testdb"

# Парсинг аргументов
while [[ $# -gt 0 ]]
do
    case "$1" in
        --port)
            PORT="$2"
            shift 2
            ;;
        --mount)
            MOUNT_POINT="$2"
            shift 2
            ;;
        --user)
            POSTGRES_USER="$2"
            shift 2
            ;;
        --password)
            POSTGRES_PASSWORD="$2"
            shift 2
            ;;
        --dbname)
            POSTGRES_DB="$2"
            shift 2
            ;;
        --dump)
            DUMP_FILE="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Неизвестный параметр: $1"
            usage
            exit 1
            ;;
    esac
done

# Проверка обязательных параметров
if [[ -z "$PORT" || -z "$MOUNT_POINT" ]]; then
    echo "Ошибка: --port и --mount обязательны."
    usage
    exit 1
fi

# Проверка установленного Docker
if ! command -v docker &> /dev/null
then
    echo "Docker не установлен. Пожалуйста, установите Docker и попробуйте снова."
    exit 1
fi

# Развёртывание PostgreSQL
echo "Развёртывание PostgreSQL на порту $PORT с точкой монтирования $MOUNT_POINT..."

docker run -d \
    --name postgres-db-$PORT \
    -e POSTGRES_USER="$POSTGRES_USER" \
    -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    -e POSTGRES_DB="$POSTGRES_DB" \
    -p "$PORT":5432 \
    -v "$MOUNT_POINT:/var/lib/postgresql/data" \
    postgres:latest

echo "Ждём запуска PostgreSQL..."
sleep 10

# Импорт дампа, если указан
if [[ -n "$DUMP_FILE" ]]; then
    echo "Копируем дамп в контейнер..."
    docker cp "$DUMP_FILE" postgres-db-$PORT:/tmp/postgres_contoso.backup

    echo "Импорт тестовых данных в PostgreSQL из .backup файла..."
    docker exec -i postgres-db-$PORT pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" /tmp/postgres_contoso.backup
    echo "Данные импортированы."
fi

echo "PostgreSQL развернут и готов на порту $PORT."
