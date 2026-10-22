#!/bin/sh
# Runs the orderservice container (http://localhost:3000).
# DB_HOST is overridden so the container reaches the DB through the published port on the host.
set -e
cd "$(dirname "$0")/.."

docker rm -f orderservice >/dev/null 2>&1 || true

docker run -d \
    --name orderservice \
    -p 3000:3000 \
    --env-file debug.env \
    -e DB_HOST=host.docker.internal \
    --add-host=host.docker.internal:host-gateway \
    orderservice

echo "Orderservice started: http://localhost:3000  (logs: docker logs -f orderservice)"