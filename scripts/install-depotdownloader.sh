#!/usr/bin/env bash

set -Eeuo pipefail

DEPOTDOWNLOADER_VERSION="${DEPOTDOWNLOADER_VERSION:-DepotDownloader_3.4.0}"
DEPOTDOWNLOADER_DIR="${DEPOTDOWNLOADER_DIR:-/opt/depotdownloader}"
DEPOTDOWNLOADER_URL="${DEPOTDOWNLOADER_URL:-https://github.com/SteamRE/DepotDownloader/releases/download/${DEPOTDOWNLOADER_VERSION}/DepotDownloader-linux-x64.zip}"

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'ERROR: required command not found: %s\n' "$1" >&2
        exit 1
    }
}

main() {
    require_command curl
    require_command unzip

    if [[ -x "${DEPOTDOWNLOADER_DIR}/DepotDownloader" ]] \
        && [[ -f "${DEPOTDOWNLOADER_DIR}/VERSION" ]] \
        && [[ "$(cat "${DEPOTDOWNLOADER_DIR}/VERSION")" == "$DEPOTDOWNLOADER_VERSION" ]]; then
        "${DEPOTDOWNLOADER_DIR}/DepotDownloader" --version
        return 0
    fi

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap "rm -rf '$tmp_dir'" EXIT

    printf 'Installing DepotDownloader %s from %s\n' "$DEPOTDOWNLOADER_VERSION" "$DEPOTDOWNLOADER_URL"
    curl -fsSL -o "${tmp_dir}/depotdownloader.zip" "$DEPOTDOWNLOADER_URL"
    mkdir -p "${tmp_dir}/extract"
    unzip -q "${tmp_dir}/depotdownloader.zip" -d "${tmp_dir}/extract"

    [[ -f "${tmp_dir}/extract/DepotDownloader" ]] || {
        printf 'ERROR: DepotDownloader binary not found in release archive.\n' >&2
        exit 1
    }

    rm -rf "$DEPOTDOWNLOADER_DIR"
    mkdir -p "$DEPOTDOWNLOADER_DIR"
    cp -a "${tmp_dir}/extract/." "$DEPOTDOWNLOADER_DIR/"
    chmod +x "${DEPOTDOWNLOADER_DIR}/DepotDownloader"
    printf '%s\n' "$DEPOTDOWNLOADER_VERSION" > "${DEPOTDOWNLOADER_DIR}/VERSION"
    printf '%s\n' "$DEPOTDOWNLOADER_URL" > "${DEPOTDOWNLOADER_DIR}/SOURCE_URL"

    "${DEPOTDOWNLOADER_DIR}/DepotDownloader" --version
}

main "$@"
