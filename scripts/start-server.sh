#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=scripts/common.sh
source /scripts/common.sh

redact_launch_args() {
    local arg
    local redacted=()

    for arg in "$@"; do
        if [[ "$arg" =~ [Pp]assword|[Tt]oken|[Ss]ecret ]]; then
            redacted+=("${arg%%=*}=<redacted>")
        elif [[ -n "${SERVER_PASSWORD:-}" && "$arg" == *"${SERVER_PASSWORD}"* ]]; then
            redacted+=("<redacted>")
        elif [[ -n "${ADMIN_PASSWORD:-}" && "$arg" == *"${ADMIN_PASSWORD}"* ]]; then
            redacted+=("<redacted>")
        elif [[ -n "${RCON_PASSWORD:-}" && "$arg" == *"${RCON_PASSWORD}"* ]]; then
            redacted+=("<redacted>")
        else
            redacted+=("$arg")
        fi
    done

    printf '%q ' "${redacted[@]}"
}

main() {
    local native_launcher
    local native_executable
    local windows_executable
    local extra_args=()
    local launch_args=()
    local query_port="${QUERY_PORT:-27015}"

    native_launcher="$(find_native_launcher)"
    native_executable="$(find_native_executable)"
    if [[ -z "$native_launcher" && -z "$native_executable" ]]; then
        windows_executable="$(find_windows_executable)"
        if [[ -n "$windows_executable" ]]; then
            die "Cannot start: only Windows server executable found (${windows_executable}). Native Linux is required for the MVP; Wine fallback is not implemented."
        fi
        die "Cannot start: no native Linux Conan server executable found under ${SERVER_DIR}."
    fi

    launch_args=(-log)

    if is_true "FORCE_QUERY_PORT_ARG" "${FORCE_QUERY_PORT_ARG:-true}"; then
        numeric_or_die "QUERY_PORT" "$query_port"
        launch_args+=("-QueryPort=${query_port}")
    fi

    if [[ -n "${MULTIHOME_IP:-}" ]]; then
        launch_args+=("-MULTIHOME=${MULTIHOME_IP}")
    fi

    if [[ -n "${MULTIHOME_HTTP_IP:-}" ]]; then
        launch_args+=("-MULTIHOMEHTTP=${MULTIHOME_HTTP_IP}")
    fi

    if [[ -n "${EXTRA_ARGS:-}" ]]; then
        read -r -a extra_args <<< "${EXTRA_ARGS}"
        launch_args+=("${extra_args[@]}")
    fi

    printf '%s\n' "$$" > "$SERVER_PID_FILE"

    if [[ -n "$native_launcher" ]]; then
        chmod +x "$native_launcher" || true
        [[ -n "$native_executable" ]] && chmod +x "$native_executable" || true
        cd "$(dirname "$native_launcher")"
        log "Launching server via verified native launcher: ${native_launcher}"
        log "Launch arguments: $(redact_launch_args "${launch_args[@]}")"
        exec "$native_launcher" "${launch_args[@]}"
    fi

    chmod +x "$native_executable" || true
    cd "$(dirname "$native_executable")"
    log "Launching native server executable directly: ${native_executable}"
    log "Launch arguments: ConanSandbox $(redact_launch_args "${launch_args[@]}")"
    exec "$native_executable" ConanSandbox "${launch_args[@]}"
}

main "$@"
