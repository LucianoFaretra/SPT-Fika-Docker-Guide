#!/bin/sh
set -eu

APP_ROOT=/opt/spt
APP_DIR="${APP_ROOT}/SPT_Runtime"
CLIENT_MOD_DIR="${APP_ROOT}/BepInEx"
RUNTIME_SOURCE=/opt/spt-dist
FIKA_SOURCE=/opt/fika-dist
FIKA_DEST="${APP_DIR}/user/mods/fika-server"
FIKA_VERSION="$(cat "${FIKA_SOURCE}/.version")"
SOURCE_SPT_VERSION="$(cat "${RUNTIME_SOURCE}/.container-spt-version")"
INSTALLED_SPT_VERSION=""
INSTALLED_VERSION=""

if [ -f "${APP_DIR}/.container-spt-version" ]; then
    INSTALLED_SPT_VERSION="$(cat "${APP_DIR}/.container-spt-version")"
fi

if [ -f "${FIKA_DEST}/.container-fika-version" ]; then
    INSTALLED_VERSION="$(cat "${FIKA_DEST}/.container-fika-version")"
fi

if [ "${INSTALLED_SPT_VERSION}" != "${SOURCE_SPT_VERSION}" ]; then
    echo "[fika-entrypoint] Installing SPT ${SOURCE_SPT_VERSION} into ${APP_DIR}"
    mkdir -p "${APP_DIR}"
    cp -a "${RUNTIME_SOURCE}/." "${APP_DIR}/"
    chown -R "${PUID:-1000}:${PGID:-1000}" "${APP_DIR}"
fi

# This is a host-side staging area for BepInEx client mods. SPT itself only
# loads the server runtime below SPT_Runtime.
mkdir -p "${CLIENT_MOD_DIR}/plugins"
if [ "$(id -u)" = "0" ]; then
    chown -R "${PUID:-1000}:${PGID:-1000}" "${CLIENT_MOD_DIR}"
fi

if [ "${INSTALLED_VERSION}" != "${FIKA_VERSION}" ]; then
    echo "[fika-entrypoint] Installing Fika Server ${FIKA_VERSION}"

    # Build the replacement beside the existing mod. Its generated configuration and
    # relation data survive upgrades, while stale DLLs and static assets are removed.
    mkdir -p "${APP_DIR}/user/mods"
    install_root="$(mktemp -d "${APP_DIR}/user/.fika-install.XXXXXX")"
    previous_root=""
    replaced=false

    cleanup() {
        if [ "${replaced}" != true ] && [ -n "${previous_root}" ] && [ -d "${previous_root}/mod" ]; then
            rm -rf "${FIKA_DEST}"
            if ! mv "${previous_root}/mod" "${FIKA_DEST}"; then
                echo "[fika-entrypoint] Failed to restore ${previous_root}/mod" >&2
            fi
        fi
        rm -rf "${install_root}"
        if [ -n "${previous_root}" ] && [ -d "${previous_root}/mod" ]; then
            echo "[fika-entrypoint] Preserved previous Fika files in ${previous_root}/mod" >&2
        elif [ -n "${previous_root}" ]; then
            rmdir "${previous_root}" 2>/dev/null || true
        fi
    }
    trap cleanup 0 1 2 15

    mkdir -p "${install_root}/mod"
    cp -a "${FIKA_SOURCE}/." "${install_root}/mod/"

    if [ -d "${FIKA_DEST}/assets/configs" ]; then
        mkdir -p "${install_root}/mod/assets/configs"
        cp -a "${FIKA_DEST}/assets/configs/." "${install_root}/mod/assets/configs/"
    fi

    if [ -d "${FIKA_DEST}/database" ]; then
        cp -a "${FIKA_DEST}/database" "${install_root}/mod/"
    fi

    printf '%s\n' "${FIKA_VERSION}" > "${install_root}/mod/.container-fika-version"
    previous_root="$(mktemp -d "${APP_DIR}/user/.fika-previous.XXXXXX")"
    if [ -d "${FIKA_DEST}" ]; then
        mv "${FIKA_DEST}" "${previous_root}/mod"
    fi
    mv "${install_root}/mod" "${FIKA_DEST}"
    replaced=true
    rmdir "${install_root}"
    rm -rf "${previous_root}"
    trap - 0 1 2 15
fi

CONFIG="${APP_DIR}/SPT_Data/configs/http.json"
SERVER_BIN="${APP_DIR}/SPT.Server.Linux"
SPT_IP="${SPT_IP:-0.0.0.0}"
SPT_PORT="${SPT_PORT:-6969}"
SPT_BACKEND_IP="${SPT_BACKEND_IP:-127.0.0.1}"
SPT_BACKEND_PORT="${SPT_BACKEND_PORT:-${SPT_PORT}}"

if [ -f "${CONFIG}" ]; then
    config_tmp="${CONFIG}.tmp"
    if jq \
        --arg ip "${SPT_IP}" \
        --argjson port "${SPT_PORT}" \
        --arg backend_ip "${SPT_BACKEND_IP}" \
        --argjson backend_port "${SPT_BACKEND_PORT}" \
        '.ip = $ip | .port = $port | .backendIp = $backend_ip | .backendPort = $backend_port' \
        "${CONFIG}" > "${config_tmp}"; then
        mv "${config_tmp}" "${CONFIG}"
        chmod 0644 "${CONFIG}"
        echo "[fika-entrypoint] Updated listen ${SPT_IP}:${SPT_PORT} and backend ${SPT_BACKEND_IP}:${SPT_BACKEND_PORT}"
    else
        rm -f "${config_tmp}"
        echo "[fika-entrypoint] WARNING: failed to rewrite ${CONFIG}" >&2
    fi
else
    echo "[fika-entrypoint] WARNING: ${CONFIG} not found; skipping network config" >&2
fi

mkdir -p "${APP_DIR}/user/mods" "${APP_DIR}/user/profiles" "${APP_DIR}/user/logs" "${APP_DIR}/user/certs"
export HOME="${APP_DIR}/user"

if [ "$(id -u)" = "0" ]; then
    PUID="${PUID:-1000}"
    PGID="${PGID:-1000}"
    chown -R "${PUID}:${PGID}" "${APP_DIR}/user"
    echo "[fika-entrypoint] Starting server as ${PUID}:${PGID}"
    exec gosu "${PUID}:${PGID}" "${SERVER_BIN}" "$@"
fi

echo "[fika-entrypoint] Starting server as $(id -u):$(id -g)"
exec "${SERVER_BIN}" "$@"
