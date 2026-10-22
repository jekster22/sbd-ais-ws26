#!/bin/sh
# To wipe the data as well: docker volume rm orderservice-db-data
docker rm -f orderservice orderservice-db 2>/dev/null || true