#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=scripts/common.sh
source /scripts/common.sh

SERVER_CHILD_PID=""
BACKUP_RAN_ON_START="false"

run_as_server_user() {
    if [[ "$(id -u)" -eq 0 ]]; then
        gosu "$RUN_USER" "$@"
    else
        "$@"
    fi
}

start_server_process() {
    if [[ "$(id -u)" -eq 0 ]]; then
        gosu "$RUN_USER" /scripts/start-server.sh &
    else
        /scripts/start-server.sh &
    fi
    SERVER_CHILD_PID="$!"
}

ensure_runtime_user() {
    local puid="${PUID:-1000}"
    local pgid="${PGID:-1000}"
    local group_name="$RUN_GROUP"

    numeric_or_die "PUID" "$puid"
    numeric_or_die "PGID" "$pgid"

    if [[ "$(id -u)" -ne 0 ]]; then
        log "Running without root initialization; mounted directory ownership will not be changed."
        return
    fi

    if getent group "$pgid" >/dev/null 2>&1; then
        group_name="$(getent group "$pgid" | cut -d: -f1)"
    elif getent group "$RUN_GROUP" >/dev/null 2>&1; then
        groupmod -g "$pgid" "$RUN_GROUP"
    else
        groupadd -g "$pgid" "$RUN_GROUP"
    fi

    if id "$RUN_USER" >/dev/null 2>&1; then
        usermod -o -u "$puid" -g "$pgid" "$RUN_USER"
    else
        useradd -m -o -u "$puid" -g "$pgid" -s /bin/bash "$RUN_USER"
    fi

    if [[ "$group_name" != "$RUN_GROUP" ]]; then
        usermod -g "$group_name" "$RUN_USER"
    fi
}

prepare_directories() {
    ensure_dir "$SERVER_DIR"
    ensure_dir "$STEAM_DIR"
    ensure_dir "$CONFIG_DIR"
    ensure_dir "$LOG_DIR"
    ensure_dir "$BACKUP_LOCATION"

    if [[ "$(id -u)" -eq 0 ]]; then
        chown -R "${PUID:-1000}:${PGID:-1000}" "$SERVER_DIR" "$STEAM_DIR" "$CONFIG_DIR" "$LOG_DIR" "$BACKUP_LOCATION"
    fi
}

seed_steam_home() {
    local steam_root="${STEAM_DIR}/.local/share/Steam"
    local steam_shortcut="${STEAM_DIR}/Steam"
    local dot_steam="${STEAM_DIR}/.steam"
    local template="/opt/steamcmd-template/Steam"

    if [[ "$(id -u)" -ne 0 ]]; then
        log "Skipping SteamCMD home seed because container is not running initialization as root."
        return 0
    fi

    if [[ ! -x "${steam_root}/steamcmd/steamcmd.sh" ]]; then
        [[ -d "$template" ]] || die "SteamCMD template is missing at ${template}"
        ensure_dir "$(dirname "$steam_root")"
        cp -a "$template" "$steam_root"
        log "Seeded SteamCMD home under ${steam_root}."
    fi

    ensure_dir "$dot_steam"
    ln -snf "$steam_root" "${dot_steam}/root"
    ln -snf "$steam_root" "${dot_steam}/steam"
    ln -snf "${steam_root}/steamcmd/linux32" "${dot_steam}/sdk32"
    ln -snf "${steam_root}/steamcmd/linux64" "${dot_steam}/sdk64"

    if [[ ! -e "$steam_shortcut" || -L "$steam_shortcut" ]]; then
        ln -snf "$steam_root" "$steam_shortcut"
    fi

    chown -R "${PUID:-1000}:${PGID:-1000}" "$STEAM_DIR"
}

log_effective_settings() {
    log "Container startup for Conan Exiles dedicated server app ${APP_ID}."
    log "Runtime: TZ=${TZ:-America/New_York}, PUID=${PUID:-1000}, PGID=${PGID:-1000}"
    log "Server: name='${SERVER_NAME:-Conan Exiles Server}', max_players=${MAX_PLAYERS:-40}, ports game=${GAME_PORT:-7777}/udp pinger=${PINGER_PORT:-7778}/udp query=${QUERY_PORT:-27015}/udp rcon=${RCON_PORT:-25575}/tcp"
    log "Passwords: server_password=$(redacted_state "${SERVER_PASSWORD:-}"), admin_password=$(redacted_state "${ADMIN_PASSWORD:-}"), rcon_password=$(redacted_state "${RCON_PASSWORD:-}")"
    log "Updates: server_on_start=${UPDATE_SERVER_ON_START:-true}, validate=${VALIDATE_SERVER_FILES:-false}, mods_on_start=${UPDATE_MODS_ON_START:-true}, auto_game_update=${AUTO_GAME_UPDATE:-false}, auto_mod_update=${AUTO_MOD_UPDATE:-false}"
    log "Backups: location=${BACKUP_LOCATION}, on_start=${BACKUP_ON_START:-true}, on_stop=${BACKUP_ON_STOP:-true}, retention_days=${BACKUP_RETENTION_DAYS:-14}"
}

run_start_backup_if_needed() {
    if is_true "BACKUP_ON_START" "${BACKUP_ON_START:-true}"; then
        if server_dir_has_content || [[ -d "$CONFIG_DIR" ]]; then
            log "Creating backup before startup update/mod operations."
            run_as_server_user /scripts/backup.sh "startup"
            BACKUP_RAN_ON_START="true"
        else
            log "Skipping startup backup because no server/config data exists yet."
        fi
    fi
}

warn_planned_features() {
    if is_true "AUTO_GAME_UPDATE" "${AUTO_GAME_UPDATE:-false}"; then
        log "AUTO_GAME_UPDATE is configured but not active in the MVP. No background game update loop will run."
    fi

    if is_true "AUTO_MOD_UPDATE" "${AUTO_MOD_UPDATE:-false}"; then
        log "AUTO_MOD_UPDATE is configured but not active in the MVP. No background mod update loop will run."
    fi
}

shutdown_server() {
    local exit_code=0

    log "Shutdown signal received."
    if [[ -n "$SERVER_CHILD_PID" ]] && kill -0 "$SERVER_CHILD_PID" >/dev/null 2>&1; then
        log "Sending graceful stop to server process ${SERVER_CHILD_PID}."
        kill -TERM "$SERVER_CHILD_PID" >/dev/null 2>&1 || true

        for _ in $(seq 1 60); do
            if ! kill -0 "$SERVER_CHILD_PID" >/dev/null 2>&1; then
                break
            fi
            sleep 1
        done

        if kill -0 "$SERVER_CHILD_PID" >/dev/null 2>&1; then
            log "Server did not stop within 60 seconds; sending SIGKILL."
            kill -KILL "$SERVER_CHILD_PID" >/dev/null 2>&1 || true
        fi

        wait "$SERVER_CHILD_PID" || exit_code=$?
    fi

    if is_true "BACKUP_ON_STOP" "${BACKUP_ON_STOP:-true}"; then
        log "Creating backup during shutdown."
        run_as_server_user /scripts/backup.sh "shutdown" || true
    fi

    exit "$exit_code"
}

main() {
    ensure_runtime_user
    prepare_directories
    seed_steam_home
    cd /serverdata

    if [[ "$#" -gt 0 ]]; then
        exec "$@"
    fi

    log_effective_settings
    warn_planned_features

    run_start_backup_if_needed

    if is_true "UPDATE_SERVER_ON_START" "${UPDATE_SERVER_ON_START:-true}" || ! server_manifest_exists; then
        run_as_server_user /scripts/update-server.sh
    else
        log "Skipping server update because UPDATE_SERVER_ON_START=false and an app manifest exists."
    fi

    run_as_server_user /scripts/configure-server.sh

    if is_true "UPDATE_MODS_ON_START" "${UPDATE_MODS_ON_START:-true}"; then
        if [[ "$BACKUP_RAN_ON_START" != "true" ]] && is_true "BACKUP_ON_START" "${BACKUP_ON_START:-true}"; then
            log "Creating backup before mod update."
            run_as_server_user /scripts/backup.sh "pre-mod-update"
        fi
        run_as_server_user /scripts/update-mods.sh
    else
        log "Skipping mod update because UPDATE_MODS_ON_START=false."
    fi

    trap shutdown_server TERM INT

    start_server_process
    wait "$SERVER_CHILD_PID"
    local exit_code=$?
    log "Server process exited with code ${exit_code}."
    exit "$exit_code"
}

main "$@"
