#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=scripts/common.sh
source /scripts/common.sh

main() {
    require_command "$STEAMCMD"

    ensure_dir "$SERVER_DIR"
    ensure_dir "$STEAM_DIR"
    ensure_dir "${LOG_DIR}/steamcmd"

    if ! is_true "UPDATE_SERVER_ON_START" "${UPDATE_SERVER_ON_START:-true}" && server_manifest_exists; then
        log "Server update skipped; existing app manifest found and UPDATE_SERVER_ON_START=false."
        return 0
    fi

    local validate_arg=()
    local validate_mode="disabled"
    if is_true "VALIDATE_SERVER_FILES" "${VALIDATE_SERVER_FILES:-false}"; then
        validate_arg=("validate")
        validate_mode="enabled"
        log "SteamCMD validation is enabled."
    fi

    local steamcmd_log
    local steamcmd_exit
    steamcmd_log="${LOG_DIR}/steamcmd/update-server-${APP_ID}-$(timestamp).log"

    log "Installing/updating Conan Exiles dedicated server app ${APP_ID} with SteamCMD."
    log "SteamCMD update details: app_id=${APP_ID}, install_path=${SERVER_DIR}, validate=${validate_mode}, log=${steamcmd_log}"
    set +e
    HOME="$STEAM_DIR" "$STEAMCMD" \
        +@ShutdownOnFailedCommand 1 \
        +@NoPromptForPassword 1 \
        +@sSteamCmdForcePlatformType linux \
        +force_install_dir "$SERVER_DIR" \
        +login anonymous \
        +app_update "$APP_ID" "${validate_arg[@]}" \
        +quit 2>&1 | tee "$steamcmd_log"
    steamcmd_exit="${PIPESTATUS[0]}"
    set -e

    if [[ "$steamcmd_exit" -ne 0 ]]; then
        log "ERROR: SteamCMD update failed: app_id=${APP_ID}, install_path=${SERVER_DIR}, validate=${validate_mode}, exit_code=${steamcmd_exit}, log=${steamcmd_log}"
        exit "$steamcmd_exit"
    fi

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
        die "SteamCMD downloaded Windows server files (${windows_executable}) but no native Linux executable was found. Wine fallback is intentionally not implemented in the MVP. SteamCMD log: ${steamcmd_log}"
    fi

    die "Server update completed but no native Linux Conan server executable was found under ${SERVER_DIR}. SteamCMD log: ${steamcmd_log}"
}

main "$@"
