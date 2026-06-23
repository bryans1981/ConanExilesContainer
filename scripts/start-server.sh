#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=scripts/common.sh
source /scripts/common.sh

main() {
    local native_executable
    local windows_executable
    local extra_args=()

    native_executable="$(find_native_executable)"
    if [[ -z "$native_executable" ]]; then
        windows_executable="$(find_windows_executable)"
        if [[ -n "$windows_executable" ]]; then
            die "Cannot start: only Windows server executable found (${windows_executable}). Native Linux is required for the MVP; Wine fallback is not implemented."
        fi
        die "Cannot start: no native Linux Conan server executable found under ${SERVER_DIR}."
    fi

    chmod +x "$native_executable" || true

    if [[ -n "${EXTRA_ARGS:-}" ]]; then
        read -r -a extra_args <<< "${EXTRA_ARGS}"
    fi

    cd "$(dirname "$native_executable")"
    printf '%s\n' "$$" > "$SERVER_PID_FILE"

    log "Launching server executable: ${native_executable}"
    log "Launch arguments: -log ${EXTRA_ARGS:-}"
    exec "$native_executable" -log "${extra_args[@]}"
}

main "$@"
