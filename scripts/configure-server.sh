#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=scripts/common.sh
source /scripts/common.sh

set_ini_value() {
    local file="$1"
    local section="$2"
    local key="$3"
    local value="$4"
    local secret="${5:-false}"
    local tmp

    ensure_dir "$(dirname "$file")"
    touch "$file"
    tmp="$(mktemp)"

    awk -v section="$section" -v key="$key" -v value="$value" '
        BEGIN {
            in_target = 0
            section_found = 0
            key_done = 0
        }
        function emit_key_if_needed() {
            if (in_target && key_done == 0) {
                print key "=" value
                key_done = 1
            }
        }
        /^\[/ {
            emit_key_if_needed()
            in_target = 0
        }
        $0 == "[" section "]" {
            section_found = 1
            in_target = 1
            print
            next
        }
        in_target == 1 && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
            print key "=" value
            key_done = 1
            next
        }
        {
            print
        }
        END {
            if (section_found == 0) {
                print ""
                print "[" section "]"
                print key "=" value
            } else {
                emit_key_if_needed()
            }
        }
    ' "$file" > "$tmp"

    mv "$tmp" "$file"

    if is_true "secret" "$secret"; then
        log "Applied config ${section}.${key}=<redacted> in ${file}"
    else
        log "Applied config ${section}.${key} in ${file}"
    fi
}

select_config_profile() {
    local saved_config="${SERVER_DIR}/ConanSandbox/Saved/Config"

    if [[ -d "${saved_config}/LinuxServer" ]]; then
        printf 'LinuxServer'
    elif [[ -d "${saved_config}/WindowsServer" ]]; then
        printf 'WindowsServer'
    else
        printf 'LinuxServer'
    fi
}

link_persistent_directory() {
    local source_dir="$1"
    local target_dir="$2"
    local label="$3"
    local backup_dir

    ensure_dir "$(dirname "$source_dir")"
    ensure_dir "$target_dir"

    if [[ -L "$source_dir" ]]; then
        if [[ "$(readlink "$source_dir")" == "$target_dir" ]]; then
            return 0
        fi
        rm "$source_dir"
    elif [[ -e "$source_dir" ]]; then
        backup_dir="${source_dir}.container-backup.$(timestamp)"
        log "Preserving existing ${label} directory at ${backup_dir} before linking persistent volume."
        cp -a "${source_dir}/." "$target_dir/" 2>/dev/null || true
        mv "$source_dir" "$backup_dir"
    fi

    ln -s "$target_dir" "$source_dir"
    log "Linked ${label}: ${source_dir} -> ${target_dir}"
}

write_default_files_if_missing() {
    local server_settings="$1"
    local engine_ini="$2"
    local game_ini="$3"

    if [[ ! -f "$server_settings" ]]; then
        cat > "$server_settings" <<'EOF'
[ServerSettings]
EOF
        log "Generated default ServerSettings.ini because it was missing."
    fi

    if [[ ! -f "$engine_ini" ]]; then
        cat > "$engine_ini" <<'EOF'
[URL]

[OnlineSubsystem]

[OnlineSubsystemSteam]
EOF
        log "Generated default Engine.ini because it was missing."
    fi

    if [[ ! -f "$game_ini" ]]; then
        cat > "$game_ini" <<'EOF'
[/Script/Engine.GameSession]
EOF
        log "Generated default Game.ini because it was missing."
    fi
}

main() {
    local max_players="${MAX_PLAYERS:-40}"
    local game_port="${GAME_PORT:-7777}"
    local pinger_port="${PINGER_PORT:-7778}"
    local query_port="${QUERY_PORT:-27015}"
    local rcon_port="${RCON_PORT:-25575}"
    local rcon_enabled
    local profile
    local persistent_config
    local server_config
    local persistent_logs
    local server_logs
    local server_settings
    local engine_ini
    local game_ini

    numeric_or_die "MAX_PLAYERS" "$max_players"
    numeric_or_die "GAME_PORT" "$game_port"
    numeric_or_die "PINGER_PORT" "$pinger_port"
    numeric_or_die "QUERY_PORT" "$query_port"
    numeric_or_die "RCON_PORT" "$rcon_port"
    rcon_enabled="$(bool_value "RCON_ENABLED" "${RCON_ENABLED:-true}")"

    profile="$(select_config_profile)"
    log "Using Conan config profile: ${profile}"

    persistent_config="${CONFIG_DIR}/ConanSandbox/Saved/Config/${profile}"
    server_config="${SERVER_DIR}/ConanSandbox/Saved/Config/${profile}"
    persistent_logs="${LOG_DIR}/ConanSandbox/Saved/Logs"
    server_logs="${SERVER_DIR}/ConanSandbox/Saved/Logs"

    link_persistent_directory "$server_config" "$persistent_config" "config"
    link_persistent_directory "$server_logs" "$persistent_logs" "logs"

    server_settings="${persistent_config}/ServerSettings.ini"
    engine_ini="${persistent_config}/Engine.ini"
    game_ini="${persistent_config}/Game.ini"

    write_default_files_if_missing "$server_settings" "$engine_ini" "$game_ini"

    set_ini_value "$server_settings" "ServerSettings" "ServerName" "${SERVER_NAME:-Conan Exiles Server}"
    set_ini_value "$server_settings" "ServerSettings" "ServerPassword" "${SERVER_PASSWORD:-}" true
    set_ini_value "$server_settings" "ServerSettings" "AdminPassword" "${ADMIN_PASSWORD:-}" true
    set_ini_value "$server_settings" "ServerSettings" "MaxPlayers" "$max_players"
    set_ini_value "$server_settings" "ServerSettings" "Port" "$game_port"
    set_ini_value "$server_settings" "ServerSettings" "PingerPort" "$pinger_port"
    set_ini_value "$server_settings" "ServerSettings" "QueryPort" "$query_port"
    set_ini_value "$server_settings" "ServerSettings" "RconEnabled" "$rcon_enabled"
    set_ini_value "$server_settings" "ServerSettings" "RconPort" "$rcon_port"
    set_ini_value "$server_settings" "ServerSettings" "RconPassword" "${RCON_PASSWORD:-}" true

    set_ini_value "$engine_ini" "URL" "Port" "$game_port"
    set_ini_value "$engine_ini" "OnlineSubsystem" "ServerName" "${SERVER_NAME:-Conan Exiles Server}"
    set_ini_value "$engine_ini" "OnlineSubsystem" "ServerPassword" "${SERVER_PASSWORD:-}" true
    set_ini_value "$engine_ini" "OnlineSubsystemSteam" "GameServerQueryPort" "$query_port"
    set_ini_value "$game_ini" "/Script/Engine.GameSession" "MaxPlayers" "$max_players"

    log "Configuration step complete."
}

main "$@"
