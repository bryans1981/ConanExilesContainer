#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=scripts/common.sh
source /scripts/common.sh

STEAMCMD_UPDATE_LOG=""
DEPOTDOWNLOADER_UPDATE_LOG=""

run_steamcmd_update() {
    require_command "$STEAMCMD"

    ensure_dir "${LOG_DIR}/steamcmd"

    local validate_arg=()
    local validate_mode="disabled"
    if is_true "VALIDATE_SERVER_FILES" "${VALIDATE_SERVER_FILES:-false}"; then
        validate_arg=("validate")
        validate_mode="enabled"
        log "SteamCMD validation is enabled."
    fi

    local steamcmd_exit
    STEAMCMD_UPDATE_LOG="${LOG_DIR}/steamcmd/update-server-${APP_ID}-$(timestamp).log"

    log "Installing/updating Conan Exiles dedicated server app ${APP_ID} with SteamCMD."
    log "SteamCMD update details: app_id=${APP_ID}, install_path=${SERVER_DIR}, validate=${validate_mode}, log=${STEAMCMD_UPDATE_LOG}"
    set +e
    HOME="$STEAM_DIR" "$STEAMCMD" \
        +@ShutdownOnFailedCommand 1 \
        +@NoPromptForPassword 1 \
        +@sSteamCmdForcePlatformType linux \
        +force_install_dir "$SERVER_DIR" \
        +login anonymous \
        +app_update "$APP_ID" "${validate_arg[@]}" \
        +quit 2>&1 | tee "$STEAMCMD_UPDATE_LOG"
    steamcmd_exit="${PIPESTATUS[0]}"
    set -e

    if [[ "$steamcmd_exit" -ne 0 ]]; then
        log "ERROR: SteamCMD update failed: app_id=${APP_ID}, install_path=${SERVER_DIR}, validate=${validate_mode}, exit_code=${steamcmd_exit}, log=${STEAMCMD_UPDATE_LOG}"
        return "$steamcmd_exit"
    fi

    return 0
}

run_depotdownloader_update() {
    require_executable "$DEPOTDOWNLOADER"

    ensure_dir "${LOG_DIR}/depotdownloader"

    local validate_arg=()
    local validate_mode="disabled"
    if is_true "VALIDATE_SERVER_FILES" "${VALIDATE_SERVER_FILES:-false}"; then
        validate_arg=("-validate")
        validate_mode="enabled"
        log "DepotDownloader validation is enabled."
    fi

    local depotdownloader_exit
    DEPOTDOWNLOADER_UPDATE_LOG="${LOG_DIR}/depotdownloader/update-server-${APP_ID}-$(timestamp).log"

    log "Installing/updating Conan Exiles dedicated server app ${APP_ID} with DepotDownloader ${DEPOTDOWNLOADER_VERSION}."
    log "DepotDownloader update details: app_id=${APP_ID}, install_path=${SERVER_DIR}, os=linux, validate=${validate_mode}, log=${DEPOTDOWNLOADER_UPDATE_LOG}"
    set +e
    HOME="$STEAM_DIR" "$DEPOTDOWNLOADER" \
        -app "$APP_ID" \
        -os linux \
        -dir "$SERVER_DIR" \
        "${validate_arg[@]}" \
        2>&1 | tee "$DEPOTDOWNLOADER_UPDATE_LOG"
    depotdownloader_exit="${PIPESTATUS[0]}"
    set -e

    if [[ "$depotdownloader_exit" -ne 0 ]]; then
        log "ERROR: DepotDownloader update failed: app_id=${APP_ID}, install_path=${SERVER_DIR}, backend=depotdownloader, validate=${validate_mode}, exit_code=${depotdownloader_exit}, log=${DEPOTDOWNLOADER_UPDATE_LOG}"
        return "$depotdownloader_exit"
    fi

    return 0
}

verify_server_executable() {
    local backend="$1"
    local backend_log="$2"
    local native_executable

    native_executable="$(find_native_executable)"
    if [[ -n "$native_executable" ]]; then
        chmod +x "$native_executable" || true
        log "Verified native Linux server executable from ${backend}: ${native_executable}"
        return 0
    fi

    local windows_executable
    windows_executable="$(find_windows_executable)"
    if [[ -n "$windows_executable" ]]; then
        die "${backend} downloaded Windows server files (${windows_executable}) but no native Linux executable was found. Wine fallback is intentionally not implemented in the MVP. Backend log: ${backend_log}"
    fi

    die "${backend} update completed but no native Linux Conan server executable was found under ${SERVER_DIR}. Backend log: ${backend_log}"
}

main() {
    local backend
    local steamcmd_exit
    local depotdownloader_exit

    backend="$(download_backend_value "${DOWNLOAD_BACKEND:-depotdownloader}")"
    ensure_dir "$SERVER_DIR"
    ensure_dir "$STEAM_DIR"

    if ! is_true "UPDATE_SERVER_ON_START" "${UPDATE_SERVER_ON_START:-true}" && server_install_exists; then
        log "Server update skipped; existing server install marker found and UPDATE_SERVER_ON_START=false."
        return 0
    fi

    log "Selected server download backend: ${backend}"

    case "$backend" in
        steamcmd)
            run_steamcmd_update || exit "$?"
            verify_server_executable "SteamCMD" "$STEAMCMD_UPDATE_LOG"
            ;;
        depotdownloader)
            run_depotdownloader_update || exit "$?"
            verify_server_executable "DepotDownloader" "$DEPOTDOWNLOADER_UPDATE_LOG"
            ;;
        auto)
            log "DOWNLOAD_BACKEND=auto: trying DepotDownloader first."
            set +e
            run_depotdownloader_update
            depotdownloader_exit="$?"
            set -e
            if [[ "$depotdownloader_exit" -eq 0 ]]; then
                log "DOWNLOAD_BACKEND=auto: DepotDownloader succeeded; SteamCMD fallback not used."
                verify_server_executable "DepotDownloader" "$DEPOTDOWNLOADER_UPDATE_LOG"
                return 0
            fi

            log "DOWNLOAD_BACKEND=auto: DepotDownloader failed with exit_code=${depotdownloader_exit}, log=${DEPOTDOWNLOADER_UPDATE_LOG}. Trying SteamCMD fallback."
            set +e
            run_steamcmd_update
            steamcmd_exit="$?"
            set -e
            if [[ "$steamcmd_exit" -ne 0 ]]; then
                log "ERROR: DOWNLOAD_BACKEND=auto failed. DepotDownloader exit_code=${depotdownloader_exit}, log=${DEPOTDOWNLOADER_UPDATE_LOG}; SteamCMD exit_code=${steamcmd_exit}, log=${STEAMCMD_UPDATE_LOG}"
                exit "$steamcmd_exit"
            fi

            verify_server_executable "SteamCMD" "$STEAMCMD_UPDATE_LOG"
            ;;
    esac
}

main "$@"
