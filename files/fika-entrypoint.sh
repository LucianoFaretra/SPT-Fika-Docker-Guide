#!/bin/sh
set -eu

APP_DIR=/opt/spt
FIKA_SOURCE=/opt/fika-dist
FIKA_DEST="${APP_DIR}/user/mods/fika-server"
FIKA_VERSION="$(cat "${FIKA_SOURCE}/.version")"
INSTALLED_VERSION=""

if [ -f "${FIKA_DEST}/.container-fika-version" ]; then
    INSTALLED_VERSION="$(cat "${FIKA_DEST}/.container-fika-version")"
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

exec /usr/local/bin/entrypoint.sh "$@"
