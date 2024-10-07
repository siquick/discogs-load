#!/bin/bash
set -e

# Check if user 'dev' exists
user_exists=$(psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='dev'" -U "$POSTGRES_USER" -d "$POSTGRES_DB")

if [ "$user_exists" != "1" ]; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        CREATE USER dev WITH PASSWORD 'dev_pass';
        ALTER USER dev WITH SUPERUSER;
        GRANT ALL PRIVILEGES ON DATABASE discogs TO dev;
EOSQL
else
    echo "User 'dev' already exists. Skipping user creation."
fi

# Create tables
for table_file in /docker-entrypoint-initdb.d/tables/*.sql
do
    echo "Executing $table_file"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f "$table_file"
done
