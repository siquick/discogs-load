#!/bin/bash

# pass in variables to the script
# ./run_server.sh --db-host "$DB_HOST" --db-port 5432 --db-user dev --db-password dev_pass --db-name discogs

set -e

# Check if discogs-load binary exists in ./target/release/
if [ ! -f "./target/release/discogs-load" ]; then
    echo "discogs-load binary not found in ./target/release/. Compiling..."
    cargo build --bin discogs-load --release
    if [ $? -ne 0 ]; then
        echo "Compilation failed. Please check your Rust installation and try again."
        exit 1
    fi
    echo "Compilation successful. Binary created at ./target/release/discogs-load"
else
    echo "discogs-load binary already exists in ./target/release/. Skipping compilation."
fi

# Download Discogs data dumps if they don't exist
for file in discogs_20240101_releases.xml.gz discogs_20240101_artists.xml.gz discogs_20240101_labels.xml.gz; do
    if [ ! -f "$file" ]; then
        echo "Downloading $file..."
        curl -O "https://discogs-data-dumps.s3-us-west-2.amazonaws.com/data/2024/$file"
    else
        echo "$file already exists. Skipping download."
    fi
done

# Start PostgreSQL container
echo "Starting PostgreSQL container..."
docker-compose up -d postgres

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
sleep 10  # Adjust this value as needed

# Run discogs-load
echo "Starting data import..."
if ! RUST_BACKTRACE=1 ./target/release/discogs-load discogs_20240101_releases.xml.gz --db-host "$DB_HOST" --db-port "$DB_PORT" --db-user "$DB_USER" --db-password "$DB_PASSWORD" --db-name "$DB_NAME"; then
    echo "Error occurred during data import. Check the output above for details."
    exit 1
fi
echo "Data import completed successfully."

# Create indexes after data insertion
echo "Creating indexes..."
if ! ./target/release/discogs-load --create-indexes --db-host "$DB_HOST" --db-port "$DB_PORT" --db-user "$DB_USER" --db-password "$DB_PASSWORD" --db-name "$DB_NAME"; then
    echo "Error occurred while creating indexes. Check the output above for details."
    exit 1
fi
echo "Indexes created successfully."

echo "Process completed. You can now query your database."
