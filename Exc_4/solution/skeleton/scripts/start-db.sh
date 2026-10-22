#!/bin/sh
# Starts the PostgreSQL container with a persistent Docker volume.
set -e
cd "$(dirname "$0")/.."

CONTAINER=orderservice-db
VOLUME=orderservice-db-data

docker volume create "$VOLUME"

if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
    echo "Container '$CONTAINER' already exists, starting it"
    docker start "$CONTAINER"
else
    docker run -d \
        --name "$CONTAINER" \
        -p 5555:5555 \
        --env-file debug.env \
        -v "$VOLUME":/var/lib/postgresql/18/docker \
        postgres:18
fi

until docker exec "$CONTAINER" pg_isready -q; do
    sleep 1
done
echo "Database is ready"