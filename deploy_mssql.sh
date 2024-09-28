#!/bin/bash

# Функция отображения справки
usage() {
    echo "Использование: $0 --port PORT --mount MOUNT_POINT [опции]"
    echo "Опции:"
    echo "  --port            Порт для MS SQL Server (обязательный)"
    echo "  --mount           Точка монтирования для данных (обязательный)"
    echo "  --sa-password     Пароль для пользователя sa (обязательный)"
    echo "  --dump            Путь к .bak файлу для восстановления"
    echo "  --help            Показать эту справку и выйти"
}

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
        --sa-password)
            SA_PASSWORD="$2"
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
if [[ -z "$PORT" || -z "$MOUNT_POINT" || -z "$SA_PASSWORD" ]]; then
    echo "Ошибка: --port, --mount и --sa-password обязательны."
    usage
    exit 1
fi

# Проверка установленного Docker
if ! command -v docker &> /dev/null
then
    echo "Docker не установлен. Пожалуйста, установите Docker и попробуйте снова."
    exit 1
fi

# Проверка существования файла дампа, если он указан
if [[ -n "$DUMP_FILE" && ! -f "$DUMP_FILE" ]]; then
    echo "Ошибка: Файл дампа '$DUMP_FILE' не найден."
    exit 1
fi

# Проверка существования директории монтирования
if [[ ! -d "$MOUNT_POINT" ]]; then
    echo "Ошибка: Точка монтирования '$MOUNT_POINT' не существует."
    exit 1
fi

# Развёртывание MS SQL Server
echo "Развёртывание MS SQL Server на порту $PORT с точкой монтирования $MOUNT_POINT..."

# Проверка и удаление существующего контейнера с таким же именем
if docker ps -a --format '{{.Names}}' | grep -Eq "^mssql-db-$PORT\$"; then
    echo "Контейнер mssql-db-$PORT уже существует. Удаляем старый контейнер..."
    docker rm -f mssql-db-$PORT
    if [[ $? -ne 0 ]]; then
        echo "Ошибка при удалении старого контейнера."
        exit 1
    fi
fi

# Запуск контейнера MS SQL Server от имени пользователя root (опция -u 0 может быть необходима для некоторых систем)
docker run -d -u 0 \
    --name mssql-db-$PORT \
    -e 'ACCEPT_EULA=Y' \
    -e "SA_PASSWORD=$SA_PASSWORD" \
    -p "$PORT":1433 \
    -v "$MOUNT_POINT:/var/opt/mssql" \
    -v "$MOUNT_POINT/backup:/var/opt/mssql/backup" \
    mcr.microsoft.com/mssql/server:2019-latest

if [[ $? -ne 0 ]]; then
    echo "Ошибка при запуске контейнера MS SQL Server."
    exit 1
fi

echo "Контейнер MS SQL Server запущен."

echo "Ждём запуска MS SQL Server..."
sleep 20

# Функция ожидания готовности MS SQL Server
wait_for_sql_server() {
    echo "Ожидание готовности MS SQL Server..."
    local retries=30
    local wait=5
    for ((i=1;i<=retries;i++)); do
        docker exec mssql-db-$PORT /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT 1" &> /dev/null
        if [[ $? -eq 0 ]]; then
            echo "MS SQL Server готов к подключениям."
            return 0
        else
            echo "MS SQL Server недоступен - попытка $i из $retries..."
            sleep $wait
        fi
    done
    echo "MS SQL Server не смог запуститься за отведённое время."
    return 1
}

# Ожидание готовности сервера
if ! wait_for_sql_server; then
    echo "Ошибка: MS SQL Server не готов."
    exit 1
fi

# Импорт дампа, если указан
if [[ -n "$DUMP_FILE" ]]; then
    echo "Начинаем импорт дампа..."

    # Создание директории для дампов внутри контейнера (уже смонтирована через -v)
    echo "Убедимся, что директория для дампов существует внутри контейнера..."
    docker exec mssql-db-$PORT mkdir -p /var/opt/mssql/backup

    if [[ $? -ne 0 ]]; then
        echo "Ошибка: Не удалось создать директорию /var/opt/mssql/backup внутри контейнера."
        exit 1
    fi

    # Копирование файла дампа в контейнер
    echo "Копирование дампа в контейнер..."
    docker cp "$DUMP_FILE" mssql-db-$PORT:/var/opt/mssql/backup/mssql_dump.bak

    if [[ $? -ne 0 ]]; then
        echo "Ошибка: Не удалось скопировать дамп в контейнер."
        exit 1
    fi

    echo "Импорт тестовых данных в MS SQL Server из .bak файла..."

    # Получение логических имен файлов из резервной копии
    echo "Получение логических имен файлов из дампа..."
    LOGICAL_NAMES=$(docker exec mssql-db-$PORT /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$SA_PASSWORD" -Q "RESTORE FILELISTONLY FROM DISK = '/var/opt/mssql/backup/mssql_dump.bak'" -s "," -W | grep -E "^[A-Za-z0-9_]+")

    if [[ -z "$LOGICAL_NAMES" ]]; then
        echo "Ошибка: Не удалось получить логические имена файлов из дампа."
        exit 1
    fi

    # Извлечение логических имен данных и логов
    LOGICAL_DATA_FILE=$(echo "$LOGICAL_NAMES" | awk -F"," '{print $1}')
    LOGICAL_LOG_FILE=$(echo "$LOGICAL_NAMES" | awk -F"," '{print $2}')

    echo "Логическое имя файла данных: $LOGICAL_DATA_FILE"
    echo "Логическое имя файла лога: $LOGICAL_LOG_FILE"

    # Определение физических имен файлов (можно задать свои или использовать существующие)
    PHYSICAL_DATA_FILE="/var/opt/mssql/data/AdventureWorks2019.mdf"
    PHYSICAL_LOG_FILE="/var/opt/mssql/data/AdventureWorks2019_log.ldf"

    # Выполнение команды восстановления базы данных с использованием правильных логических имен
    docker exec -i mssql-db-$PORT /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$SA_PASSWORD" -Q "
    RESTORE DATABASE [AdventureWorks2019] 
    FROM DISK = N'/var/opt/mssql/backup/mssql_dump.bak' 
    WITH 
        MOVE 'AdventureWorks2019' TO '/var/opt/mssql/data/AdventureWorks2019.mdf', 
        MOVE 'AdventureWorks2019_log' TO '/var/opt/mssql/data/AdventureWorks2019_log.ldf', 
        REPLACE;
    "

    if [[ $? -eq 0 ]]; then
        echo "Данные успешно импортированы."
    else
        echo "Ошибка при импорте данных."
        exit 1
    fi
fi

echo "MS SQL Server развернут и готов на порту $PORT."
