#!/bin/sh
# Builds the orderservice image using the multi-stage Dockerfile.
set -e
cd "$(dirname "$0")/.."

docker build -t orderservice .