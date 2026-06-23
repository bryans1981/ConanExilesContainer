#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=scripts/common.sh
source /scripts/common.sh

if [[ -f "$SERVER_PID_FILE" ]]; then
    pid="$(cat "$SERVER_PID_FILE")"
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" >/dev/null 2>&1; then
        exit 0
    fi
fi

if pgrep -f 'Conan.*Server.*Linux' >/dev/null 2>&1; then
    exit 0
fi

exit 1
