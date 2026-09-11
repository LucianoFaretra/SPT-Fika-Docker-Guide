#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "${SCRIPT_DIR}"

if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created .env from .env.example. Configure it, then run ./update.sh again."
    exit 1
fi

# .env is intentionally limited to shell-compatible KEY=value lines.
set -a
. ./.env
set +a

: "${SPT_VERSION:?SPT_VERSION must be set in .env}"
: "${SPT_DIGEST:?SPT_DIGEST must be set in .env}"
: "${FIKA_VERSION:?FIKA_VERSION must be set in .env}"
BACKUP_DIR="${BACKUP_DIR:-backups}"

if ! docker compose version >/dev/null 2>&1; then
    echo "Docker Compose v2 is required." >&2
    exit 1
fi

echo "Building SPT ${SPT_VERSION} with Fika Server ${FIKA_VERSION}"
docker compose build --pull

echo "Stopping the server before backing up persistent data"
docker compose stop

if [ -d spt-user ]; then
    timestamp="$(date +%Y%m%d-%H%M%S)"
    mkdir -p "${BACKUP_DIR}"
    backup_file="${BACKUP_DIR}/spt-user-${timestamp}.tar.gz"
    echo "Creating backup ${backup_file}"
    tar -czf "${backup_file}" -C spt-user .
fi

docker compose up -d --force-recreate --remove-orphans
docker compose ps
echo "Update complete. Follow startup logs with: docker compose logs -f fika-server"
