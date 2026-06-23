#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=scripts/common.sh
source /scripts/common.sh

main() {
    local native_launcher
    local native_executable
    local windows_executable
    local extra_args=()

    native_launcher="$(find_native_launcher)"
    native_executable="$(find_native_executable)"
    if [[ -z "$native_launcher" && -z "$native_executable" ]]; then
        windows_executable="$(find_windows_executable)"
        if [[ -n "$windows_executable" ]]; then
            die "Cannot start: only Windows server executable found (${windows_executable}). Native Linux is required for the MVP; Wine fallback is not implemented."
        fi
        die "Cannot start: no native Linux Conan server executable found under ${SERVER_DIR}."
    fi

    if [[ -n "${EXTRA_ARGS:-}" ]]; then
        read -r -a extra_args <<< "${EXTRA_ARGS}"
    fi

    printf '%s\n' "$$" > "$SERVER_PID_FILE"

    if [[ -n "$native_launcher" ]]; then
        chmod +x "$native_launcher" || true
        [[ -n "$native_executable" ]] && chmod +x "$native_executable" || true
        cd "$(dirname "$native_launcher")"
        log "Launching server via verified native launcher: ${native_launcher}"
        log "Launch arguments: -log ${EXTRA_ARGS:-}"
        exec "$native_launcher" -log "${extra_args[@]}"
    fi

    chmod +x "$native_executable" || true
    cd "$(dirname "$native_executable")"
    log "Launching native server executable directly: ${native_executable}"
    log "Launch arguments: ConanSandbox -log ${EXTRA_ARGS:-}"
    exec "$native_executable" ConanSandbox -log "${extra_args[@]}"
}

main "$@"
