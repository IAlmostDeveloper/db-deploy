# Database Deployment Scripts

Данный проект предоставляет скрипты для развертывания различных баз данных (MySQL, PostgreSQL, MS SQL Server) с использованием Docker. Скрипты предназначены для использования на виртуальных машинах с операционной системой Linux.

## Требования

- Установленный Docker
- Linux виртуальная машина

## Скрипты

Скрипты развертывают следующие базы данных:

1. **MySQL**
   - Скрипт: `deploy_mysql.sh`
   - Запуск:
     ```bash
     ./deploy_mysql.sh --port 3308 --user mysql --password mysql --root-password root --dbname testdb123 --mount /path/to/mysql/data --dump-dir dumps/mysql_test_db
     ```

2. **PostgreSQL**
   - Скрипт: `deploy_postgres.sh`
   - Запуск:
     ```bash
     ./deploy_postgres.sh --port 5433 --mount /path/to/postgres/data --user postgres --password postgres --dbname testdb123 --dump /dumps/postgres_contoso.backup
     ```

3. **MS SQL Server**
   - Скрипт: `deploy_mssql.sh`
   - Запуск:
     ```bash
     ./deploy_mssql.sh --port 1434 --mount /path/to/mssql/data --sa-password Adminpass@1 --dump dumps/mssql_adventureworks2019.bak
     ```

## Описание параметров

Каждый скрипт принимает следующие параметры:

### MySQL (deploy_mysql.sh)

- `--port`: Порт для MySQL (обязательный)
- `--user`: Имя пользователя MySQL (по умолчанию: `mysql`)
- `--password`: Пароль пользователя MySQL (по умолчанию: `mysql`)
- `--root-password`: Пароль для root пользователя (обязательный)
- `--dbname`: Имя базы данных (по умолчанию: `testdb`)
- `--mount`: Точка монтирования для данных (обязательная)
- `--dump-dir`: Директория для дампов

### PostgreSQL (deploy_postgres.sh)

- `--port`: Порт для PostgreSQL (обязательный)
- `--mount`: Точка монтирования для данных (обязательная)
- `--user`: Имя пользователя PostgreSQL (по умолчанию: `admin`)
- `--password`: Пароль пользователя PostgreSQL (по умолчанию: `adminpass`)
- `--dbname`: Имя базы данных PostgreSQL (по умолчанию: `testdb`)
- `--dump`: Путь к .backup файлу для восстановления

### MS SQL Server (deploy_mssql.sh)

- `--port`: Порт для MS SQL Server (обязательный)
- `--mount`: Точка монтирования для данных (обязательная)
- `--sa-password`: Пароль для пользователя sa (обязательный)
- `--dump`: Путь к .bak файлу для восстановления

## Установка и запуск

1. Убедитесь, что Docker установлен и работает на вашей виртуальной машине.
2. Склонируйте этот репозиторий или скачайте скрипты.
3. Запустите нужный скрипт с необходимыми параметрами.

## Примечания

- Перед запуском убедитесь, что указанная точка монтирования существует.
- Если у вас возникли проблемы с запуском, проверьте, что Docker установлен и доступен в PATH.

## Лицензия

Этот проект лицензирован под лицензией MIT. См. файл LICENSE для получения дополнительной информации.
