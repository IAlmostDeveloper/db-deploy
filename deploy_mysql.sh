#!/bin/bash

# Функция отображения справки
usage() {
    echo "Использование: $0 --port PORT --mount MOUNT_POINT --root-password ROOT_PASSWORD [опции]"
    echo "Опции:"
    echo "  --port            Порт для MySQL (обязательный)"
    echo "  --mount           Точка монтирования для данных (обязательный)"
    echo "  --root-password   Пароль для root пользователя MySQL (обязательный)"
    echo "  --user            Имя пользователя MySQL (по умолчанию: user)"
    echo "  --password        Пароль для пользователя MySQL (по умолчанию: userpass)"
    echo "  --dbname          Имя базы данных MySQL (по умолчанию: testdb)"
    echo "  --dump-dir        Путь к директории с SQL дампами для импорта"
    echo "  --help            Показать эту справку и выйти"
}

# Значения по умолчанию
MYSQL_USER="user"
MYSQL_PASSWORD="userpass"
MYSQL_DB="testdb"

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
        --root-password)
            ROOT_PASSWORD="$2"
            shift 2
            ;;
        --user)
            MYSQL_USER="$2"
            shift 2
            ;;
        --password)
            MYSQL_PASSWORD="$2"
            shift 2
            ;;
        --dbname)
            MYSQL_DB="$2"
            shift 2
            ;;
        --dump-dir)
            DUMP_DIR="$2"
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
if [[ -z "$PORT" || -z "$MOUNT_POINT" || -z "$ROOT_PASSWORD" ]]; then
    echo "Ошибка: --port, --mount и --root-password обязательны."
    usage
    exit 1
fi

# Проверка установленного Docker
if ! command -v docker &> /dev/null
then
    echo "Docker не установлен. Пожалуйста, установите Docker и попробуйте снова."
    exit 1
fi

# Проверка существования директории с дампами, если она указана
if [[ -n "$DUMP_DIR" && ! -d "$DUMP_DIR" ]]; then
    echo "Ошибка: Директория с дампами '$DUMP_DIR' не существует."
    exit 1
fi

# Получение абсолютного пути к директории с дампами
if [[ -n "$DUMP_DIR" ]]; then
    DUMP_DIR_ABS=$(realpath "$DUMP_DIR")
else
    DUMP_DIR_ABS=""
fi

# Развёртывание MySQL
echo "Развёртывание MySQL на порту $PORT с точкой монтирования $MOUNT_POINT..."

docker run -d \
    --name mysql-db-$PORT \
    -e MYSQL_ROOT_PASSWORD="$ROOT_PASSWORD" \
    -e MYSQL_DATABASE="$MYSQL_DB" \
    -e MYSQL_USER="$MYSQL_USER" \
    -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
    -p "$PORT":3306 \
    -v "$MOUNT_POINT:/var/lib/mysql" \
    mysql:latest

echo "Ждём запуска MySQL..."

# Цикл ожидания готовности MySQL
MAX_TRIES=30
TRY=1
until docker exec mysql-db-$PORT mysqladmin ping -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --silent; do
    if [ $TRY -gt $MAX_TRIES ]; then
        echo "MySQL не смог запуститься за отведённое время."
        exit 1
    fi
    echo "MySQL недоступен - попытка $TRY из $MAX_TRIES..."
    sleep 2
    TRY=$((TRY+1))
done

echo "MySQL запущен и готов к подключениям."

# Импорт дампа, если указана директория с дампами
if [[ -n "$DUMP_DIR_ABS" ]]; then
    # Создание временной директории внутри контейнера
    TEMP_DIR="/tmp/mysql_dumps_$PORT"
    docker exec mysql-db-$PORT mkdir -p "$TEMP_DIR"

    # Копирование всех SQL файлов из директории с дампами в контейнер
    echo "Копирование дампов из '$DUMP_DIR_ABS' в контейнер..."
    docker cp "$DUMP_DIR_ABS/." mysql-db-$PORT:"$TEMP_DIR"

    # Определение основного SQL файла для импорта
    MAIN_SQL_FILE="$TEMP_DIR/employees.sql"

    if [[ ! -f "$DUMP_DIR_ABS/employees.sql" ]]; then
        echo "Ошибка: Основной SQL файл 'employees.sql' не найден в директории дампов."
        exit 1
    fi

    echo "Импорт тестовых данных в MySQL из 'employees.sql' и зависимых файлов..."


    sleep 15
    IMPORT_COMMAND="cd /tmp/mysql_dumps_$PORT && mysql -u\"root\" -p\"root\" \"$MYSQL_DB\" < \"$MAIN_SQL_FILE\""
    echo $IMPORT_COMMAND
    # Выполнение основного SQL файла внутри контейнера
    docker exec mysql-db-$PORT bash -c "$IMPORT_COMMAND"

    if [[ $? -eq 0 ]]; then
        echo "Данные успешно импортированы."
    else
        echo "Ошибка при импорте данных."
        exit 1
    fi
fi

echo "MySQL развернут и готов на порту $PORT."
