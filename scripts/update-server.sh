#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=scripts/common.sh
source /scripts/common.sh

main() {
    require_command "$STEAMCMD"

    ensure_dir "$SERVER_DIR"
    ensure_dir "$STEAM_DIR"

    if ! is_true "UPDATE_SERVER_ON_START" "${UPDATE_SERVER_ON_START:-true}" && server_manifest_exists; then
        log "Server update skipped; existing app manifest found and UPDATE_SERVER_ON_START=false."
        return 0
    fi

    local validate_arg=()
    if is_true "VALIDATE_SERVER_FILES" "${VALIDATE_SERVER_FILES:-false}"; then
        validate_arg=("validate")
        log "SteamCMD validation is enabled."
    fi

    log "Installing/updating Conan Exiles dedicated server app ${APP_ID} with SteamCMD."
    HOME="$STEAM_DIR" "$STEAMCMD" \
        +@ShutdownOnFailedCommand 1 \
        +@NoPromptForPassword 1 \
        +@sSteamCmdForcePlatformType linux \
        +force_install_dir "$SERVER_DIR" \
        +login anonymous \
        +app_update "$APP_ID" "${validate_arg[@]}" \
        +quit

    local native_executable
    native_executable="$(find_native_executable)"
    if [[ -n "$native_executable" ]]; then
        chmod +x "$native_executable" || true
        log "Verified native Linux server executable: ${native_executable}"
        return 0
    fi

    local windows_executable
    windows_executable="$(find_windows_executable)"
    if [[ -n "$windows_executable" ]]; then
        die "SteamCMD downloaded Windows server files (${windows_executable}) but no native Linux executable was found. Wine fallback is intentionally not implemented in the MVP."
    fi

    die "Server update completed but no native Linux Conan server executable was found under ${SERVER_DIR}."
}

main "$@"
