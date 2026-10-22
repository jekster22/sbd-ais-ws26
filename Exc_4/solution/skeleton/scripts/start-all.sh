#!/bin/sh
# One-shot: start DB, build image, run orderservice.
set -e
cd "$(dirname "$0")"

./start-db.sh
./build-orderservice.sh
./run-orderservice.sh