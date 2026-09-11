#!/bin/sh
set -eu

SOURCE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TARGET_DIR="${1:-${PWD}/containers/fika}"

mkdir -p "${TARGET_DIR}"

for file in Dockerfile compose.yaml fika-entrypoint.sh update.sh .dockerignore .env.example; do
    if [ -e "${TARGET_DIR}/${file}" ]; then
        echo "Keeping existing ${TARGET_DIR}/${file}"
    else
        cp "${SOURCE_DIR}/${file}" "${TARGET_DIR}/${file}"
        echo "Created ${TARGET_DIR}/${file}"
    fi
done

chmod +x "${TARGET_DIR}/fika-entrypoint.sh" "${TARGET_DIR}/update.sh"

if [ ! -f "${TARGET_DIR}/.env" ]; then
    cp "${TARGET_DIR}/.env.example" "${TARGET_DIR}/.env"
    echo "Created ${TARGET_DIR}/.env. Set PUID and PGID before updating."
fi

echo "Setup complete. Run ${TARGET_DIR}/update.sh to build and start the server."
