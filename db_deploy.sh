#!/bin/bash

# Получаем текущую директорию, где лежат дампы
CURRENT_DIR=$(dirname "$0")

# Проверка, что Docker установлен
if ! command -v docker &> /dev/null
then
    echo "Docker не установлен. Пожалуйста, установите Docker и попробуйте снова."
    exit 1
fi

# Функция для развёртывания PostgreSQL с указанием порта, монтирования и импортом дампа (.backup)
deploy_postgres() {
    local port=$1
    local mount_point=$2
    echo "Развёртывание PostgreSQL на порту $port с точкой монтирования $mount_point..."

    docker run -d \
        --name postgres-db-$port \
        -e POSTGRES_USER=admin \
        -e POSTGRES_PASSWORD=adminpass \
        -e POSTGRES_DB=testdb \
        -p $port:5432 \
        -v "$mount_point:/var/lib/postgresql/data" \
        postgres:latest

    echo "Ждём запуска PostgreSQL..."
    sleep 10

    echo "Импорт тестовых данных в PostgreSQL из .backup файла..."
    docker exec -i postgres-db-$port pg_restore -U admin -d testdb < "$CURRENT_DIR/dumps/postgres_contoso.backup"

    echo "PostgreSQL развернут и данные импортированы на порту $port."
}

# Функция для развёртывания MS SQL Server с указанием порта, монтирования и импортом дампа (.bak)
deploy_mssql() {
    local port=$1
    local mount_point=$2
    echo "Развёртывание MS SQL Server на порту $port с точкой монтирования $mount_point..."

    docker run -d \
        --name mssql-db-$port \
        -e 'ACCEPT_EULA=Y' \
        -e 'SA_PASSWORD=YourStrong@Passw0rd' \
        -p $port:1433 \
        -v "$mount_point:/var/opt/mssql" \
        mcr.microsoft.com/mssql/server:2019-latest

    echo "Ждём запуска MS SQL Server..."
    sleep 20

    echo "Импорт тестовых данных в MS SQL Server из .bak файла..."
    docker exec -i mssql-db-$port /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -Q "
    RESTORE DATABASE [TestDB] FROM DISK = N'/var/opt/mssql/backup/mssql_dump.bak' WITH MOVE 'TestDB' TO '/var/opt/mssql/data/TestDB.mdf', MOVE 'TestDB_log' TO '/var/opt/mssql/data/TestDB_log.ldf', REPLACE;
    "

    echo "MS SQL Server развернут и данные импортированы на порту $port."
}

# Функция для развёртывания MySQL с указанием порта, монтирования и импортом дампа (.sql)
deploy_mysql() {
    local port=$1
    local mount_point=$2
    echo "Развёртывание MySQL на порту $port с точкой монтирования $mount_point..."

    docker run -d \
        --name mysql-db-$port \
        -e MYSQL_ROOT_PASSWORD=rootpass \
        -e MYSQL_DATABASE=testdb \
        -e MYSQL_USER=user \
        -e MYSQL_PASSWORD=userpass \
        -p $port:3306 \
        -v "$mount_point:/var/lib/mysql" \
        mysql:latest

    echo "Ждём запуска MySQL..."
    sleep 15

    echo "Импорт тестовых данных в MySQL из .sql файла..."
    docker exec -i mysql-db-$port mysql -uuser -puserpass testdb < "$CURRENT_DIR/dumps/mysql_test_db/employees.sql"

    echo "MySQL развернут и данные импортированы на порту $port."
}

# Проверка переданных аргументов и развёртывание соответствующих баз данных с указанными портами и точками монтирования
while [[ $# -gt 0 ]]
do
    db=$1
    port=$2
    mount_point=$3
    shift 3

    case $db in
        postgres)
            deploy_postgres $port $mount_point
            ;;
        mssql)
            deploy_mssql $port $mount_point
            ;;
        mysql)
            deploy_mysql $port $mount_point
            ;;
        *)
            echo "Неизвестная СУБД: $db. Доступные варианты: postgres, mssql, mysql."
            ;;
    esac
done
