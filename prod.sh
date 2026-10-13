#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e
set -o pipefail

action="${1:-up}"
if [ "$#" -gt 1 ]; then
    echo "Usage: $0 [up|down]" >&2
    exit 1
fi
case "$action" in
    up|down) ;;
    *)
        echo "Usage: $0 [up|down]" >&2
        exit 1
        ;;
esac

# Resolve the project and environment file relative to this script.
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
export ENV_FILE=.env.prod

case "$action" in
    up)
        echo "Starting containers using .env.prod..."
        docker compose -f docker-compose.yml --env-file "$ENV_FILE" config --quiet
        docker compose -f docker-compose.yml --env-file "$ENV_FILE" up -d
        echo "Docker compose started successfully!"
        ;;
    down)
        echo "Stopping containers using .env.prod..."
        docker compose -f docker-compose.yml --env-file "$ENV_FILE" down
        echo "Docker compose stopped successfully!"
        ;;
esac
