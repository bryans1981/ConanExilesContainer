#!/usr/bin/env bash

set -Eeuo pipefail

APP_ID="${APP_ID:-443030}"
WORKSHOP_APP_ID="${WORKSHOP_APP_ID:-440900}"
SERVER_DIR="${SERVER_DIR:-/serverdata/serverfiles}"
STEAM_DIR="${STEAM_DIR:-/serverdata/steam}"
CONFIG_DIR="${CONFIG_DIR:-/serverdata/config}"
LOG_DIR="${LOG_DIR:-/serverdata/logs}"
BACKUP_LOCATION="${BACKUP_LOCATION:-/serverdata/backups}"
STEAMCMD="${STEAMCMD:-steamcmd}"
DOWNLOAD_BACKEND="${DOWNLOAD_BACKEND:-steamcmd}"
DEPOTDOWNLOADER="${DEPOTDOWNLOADER:-/opt/depotdownloader/DepotDownloader}"
DEPOTDOWNLOADER_VERSION="${DEPOTDOWNLOADER_VERSION:-DepotDownloader_3.4.0}"
SERVER_PID_FILE="${SERVER_PID_FILE:-/tmp/conan-server.pid}"
RUN_USER="${RUN_USER:-conan}"
RUN_GROUP="${RUN_GROUP:-conan}"

timestamp() {
    date -u +"%Y%m%dT%H%M%SZ"
}

log() {
    printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

die() {
    log "ERROR: $*"
    exit 1
}

to_lower() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

bool_value() {
    local name="$1"
    local value="${2:-}"

    case "$(to_lower "$value")" in
        true|yes|1)
            printf 'true'
            ;;
        false|no|0|'')
            printf 'false'
            ;;
        *)
            die "Invalid boolean for ${name}: '${value}'. Use true/false, yes/no, or 1/0."
            ;;
    esac
}

is_true() {
    local name="$1"
    local value="${2:-}"
    [[ "$(bool_value "$name" "$value")" == "true" ]]
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_executable() {
    [[ -x "$1" ]] || die "Required executable not found or not executable: $1"
}

ensure_dir() {
    mkdir -p "$1"
}

redacted_state() {
    local value="${1:-}"
    if [[ -n "$value" ]]; then
        printf 'set'
    else
        printf 'empty'
    fi
}

normalize_csv() {
    local raw="${1:-}"
    awk -v RS=',' '{
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
        if ($0 != "") {
            print $0
        }
    }' <<< "$raw"
}

numeric_or_die() {
    local name="$1"
    local value="$2"
    [[ "$value" =~ ^[0-9]+$ ]] || die "${name} must be numeric; got '${value}'"
}

positive_or_zero_or_die() {
    local name="$1"
    local value="$2"
    numeric_or_die "$name" "$value"
}

server_manifest_exists() {
    [[ -f "${SERVER_DIR}/steamapps/appmanifest_${APP_ID}.acf" ]]
}

server_install_exists() {
    local native_executable
    local windows_executable

    if server_manifest_exists; then
        return 0
    fi

    native_executable="$(find_native_executable)"
    if [[ -n "$native_executable" ]]; then
        return 0
    fi

    windows_executable="$(find_windows_executable)"
    if [[ -n "$windows_executable" ]]; then
        return 0
    fi

    return 1
}

download_backend_value() {
    local value="${1:-steamcmd}"

    case "$(to_lower "$value")" in
        steamcmd)
            printf 'steamcmd'
            ;;
        depotdownloader)
            printf 'depotdownloader'
            ;;
        auto)
            printf 'auto'
            ;;
        *)
            die "Invalid DOWNLOAD_BACKEND: '${value}'. Use steamcmd, depotdownloader, or auto."
            ;;
    esac
}

server_dir_has_content() {
    [[ -d "$SERVER_DIR" ]] && find "$SERVER_DIR" -mindepth 1 -maxdepth 2 -print -quit | grep -q .
}

find_native_executable() {
    if [[ ! -d "$SERVER_DIR" ]]; then
        return 0
    fi

    find "$SERVER_DIR" \
        -type f \
        -path '*/Binaries/Linux/*' \
        \( -name 'ConanSandboxServer*' -o -name '*Conan*Server*Linux*' \) \
        -print | sort | head -n 1
}

find_native_launcher() {
    if [[ ! -d "$SERVER_DIR" ]]; then
        return 0
    fi

    find "$SERVER_DIR" \
        -maxdepth 2 \
        -type f \
        -name 'ConanSandboxServer.sh' \
        -print | sort | head -n 1
}

find_windows_executable() {
    if [[ ! -d "$SERVER_DIR" ]]; then
        return 0
    fi

    find "$SERVER_DIR" \
        -type f \
        -path '*/Binaries/Win64/*' \
        \( -name 'ConanSandboxServer*.exe' -o -name '*Conan*Server*.exe' \) \
        -print | sort | head -n 1
}
