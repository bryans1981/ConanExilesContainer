#!/usr/bin/env bash

set -Eeuo pipefail

STRICT_STEAM_FAILURES="false"
SKIP_DNS_OVERRIDE="false"
SKIP_APP_UPDATE_ATTEMPT="false"
SKIP_HOST_NETWORK="false"
LOG_ROOT=""

usage() {
    cat <<'EOF'
Usage: tests/steamcmd-connectivity.sh [options]

Options:
  --log-root PATH             Write logs under PATH.
  --strict-steam-failures     Exit nonzero when a SteamCMD check fails.
  --skip-dns-override         Skip public DNS override checks.
  --skip-app-update-attempt   Skip the bounded AppID 443030 update attempt.
  --skip-host-network         Skip optional Docker host-networking check.
  -h, --help                  Show this help.
EOF
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --log-root)
            LOG_ROOT="$2"
            shift 2
            ;;
        --strict-steam-failures)
            STRICT_STEAM_FAILURES="true"
            shift
            ;;
        --skip-dns-override)
            SKIP_DNS_OVERRIDE="true"
            shift
            ;;
        --skip-app-update-attempt)
            SKIP_APP_UPDATE_ATTEMPT="true"
            shift
            ;;
        --skip-host-network)
            SKIP_HOST_NETWORK="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_ID="${APP_ID:-443030}"
PROJECT_IMAGE="${PROJECT_IMAGE:-conan-exiles-container:local}"
STEAMCMD_IMAGE="${STEAMCMD_IMAGE:-steamcmd/steamcmd:ubuntu-24}"

if [[ -z "$LOG_ROOT" ]]; then
    LOG_ROOT="${REPO_ROOT}/test-results/steamcmd-connectivity/$(date -u +%Y%m%dT%H%M%SZ)-$$"
fi

mkdir -p "$LOG_ROOT"
SUMMARY_PATH="${LOG_ROOT}/summary.txt"
INCONCLUSIVE_COUNT=0
STEAM_FAILURE_COUNT=0
FAILURE_COUNT=0

add_summary_line() {
    printf '%s\n' "$*" >> "$SUMMARY_PATH"
}

run_check() {
    local name="$1"
    local description="$2"
    local allow_inconclusive="$3"
    local steam_check="$4"
    shift 4

    local log_path="${LOG_ROOT}/${name}.raw.log"
    printf '\n== %s ==\n%s\n' "$name" "$description"
    {
        printf 'Name: %s\n' "$name"
        printf 'Description: %s\n' "$description"
        printf 'StartedUtc: %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf 'Command:'
        printf ' %q' "$@"
        printf '\n\n'
    } > "$log_path"

    set +e
    "$@" >> "$log_path" 2>&1
    local exit_code="$?"
    set -e

    local status
    if [[ "$exit_code" -eq 0 ]]; then
        status="PASS"
    elif [[ "$allow_inconclusive" == "true" ]]; then
        status="INCONCLUSIVE"
        INCONCLUSIVE_COUNT=$((INCONCLUSIVE_COUNT + 1))
        if [[ "$steam_check" == "true" ]]; then
            STEAM_FAILURE_COUNT=$((STEAM_FAILURE_COUNT + 1))
        fi
    else
        status="FAIL"
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
    fi

    printf '%s exit=%s log=%s\n' "$status" "$exit_code" "$log_path"
    add_summary_line "$status $name exit=$exit_code log=$log_path"
}

add_skip() {
    local name="$1"
    local reason="$2"
    printf '\n== %s ==\nINCONCLUSIVE %s\n' "$name" "$reason"
    add_summary_line "INCONCLUSIVE $name skipped: $reason"
    INCONCLUSIVE_COUNT=$((INCONCLUSIVE_COUNT + 1))
}

cd "$REPO_ROOT"
cat > "$SUMMARY_PATH" <<EOF
SteamCMD connectivity diagnostics
StartedUtc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
RepoRoot=${REPO_ROOT}
LogRoot=${LOG_ROOT}
AppId=${APP_ID}

EOF

run_check "host-dns" "Resolve public hostnames from the Codex host. No LAN hosts are contacted." "true" "false" \
    bash -lc 'if command -v getent >/dev/null 2>&1; then getent hosts github.com steamcdn-a.akamaihd.net steamcommunity.com; elif command -v nslookup >/dev/null 2>&1; then nslookup github.com && nslookup steamcdn-a.akamaihd.net && nslookup steamcommunity.com; else echo "No host DNS lookup tool found"; exit 1; fi'

run_check "host-https" "Fetch a public HTTPS endpoint from the Codex host. No LAN hosts are contacted." "true" "false" \
    bash -lc 'if command -v curl >/dev/null 2>&1; then curl -fsS --max-time 20 https://api.github.com >/dev/null; elif command -v wget >/dev/null 2>&1; then wget -q -T 20 -O /dev/null https://api.github.com; else echo "No host HTTPS client found"; exit 1; fi'

run_check "docker-version" "Verify Docker client/server are available." "false" "false" \
    docker version

run_check "container-dns-default" "Resolve GitHub, Steam CDN, and Steam community names from a simple container." "true" "false" \
    docker run --rm busybox:1.36 sh -lc 'nslookup github.com && nslookup steamcdn-a.akamaihd.net && nslookup media.steampowered.com && nslookup steamcommunity.com'

run_check "container-https-default" "Check HTTPS access to GitHub API and SteamCMD installer from a simple container." "true" "false" \
    docker run --rm curlimages/curl:8.10.1 sh -lc 'curl -fsSIL --max-time 20 https://api.github.com >/dev/null && curl -fsSIL --max-time 20 https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz >/dev/null'

run_check "container-package-repository" "Check Ubuntu package repository reachability from a container." "true" "false" \
    docker run --rm ubuntu:24.04 bash -lc 'apt-get update -qq'

if [[ "$SKIP_DNS_OVERRIDE" != "true" ]]; then
    run_check "dns-override-1-1-1-1" "Repeat DNS checks with Docker --dns 1.1.1.1." "true" "false" \
        docker run --rm --dns 1.1.1.1 busybox:1.36 sh -lc 'nslookup steamcdn-a.akamaihd.net && nslookup media.steampowered.com && nslookup steamcommunity.com'

    run_check "dns-override-8-8-8-8" "Repeat DNS checks with Docker --dns 8.8.8.8." "true" "false" \
        docker run --rm --dns 8.8.8.8 busybox:1.36 sh -lc 'nslookup steamcdn-a.akamaihd.net && nslookup media.steampowered.com && nslookup steamcommunity.com'

    run_check "steamcmd-upstream-login-dns-1-1-1-1" "Try upstream SteamCMD anonymous login with Docker --dns 1.1.1.1." "true" "true" \
        docker run --rm --dns 1.1.1.1 "$STEAMCMD_IMAGE" +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit
fi

PROJECT_IMAGE_AVAILABLE="false"
if docker image inspect "$PROJECT_IMAGE" >/dev/null 2>&1; then
    PROJECT_IMAGE_AVAILABLE="true"
    run_check "project-image-present" "Inspect the local project image." "false" "false" \
        docker image inspect "$PROJECT_IMAGE" --format '{{.Id}} {{.Created}}'
else
    add_skip "project-image-present" "Project image ${PROJECT_IMAGE} is not available. Run docker compose build first."
fi

if [[ "$PROJECT_IMAGE_AVAILABLE" == "true" ]]; then
    volume_arg="${LOG_ROOT}:/diagnostics"
    run_check "steamcmd-project-login" "Try SteamCMD anonymous login through this project image and compose entrypoint." "true" "true" \
        docker compose run --rm -v "$volume_arg" conan timeout 180s gosu conan env HOME=/serverdata/steam steamcmd +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit

    run_check "steamcmd-project-app-info" "Try SteamCMD app info for AppID 443030 through this project image." "true" "true" \
        docker compose run --rm -v "$volume_arg" conan timeout 240s gosu conan env HOME=/serverdata/steam steamcmd +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +app_info_print "$APP_ID" +quit

    if [[ "$SKIP_APP_UPDATE_ATTEMPT" != "true" ]]; then
        run_check "steamcmd-project-app-update" "Try the project update script for AppID 443030 with a 300 second timeout." "true" "true" \
            docker compose run --rm -v "$volume_arg" conan timeout 300s gosu conan env HOME=/serverdata/steam /scripts/update-server.sh
    else
        add_skip "steamcmd-project-app-update" "Skipped by --skip-app-update-attempt."
    fi
fi

run_check "steamcmd-upstream-login" "Try SteamCMD anonymous login with upstream steamcmd/steamcmd:ubuntu-24." "true" "true" \
    docker run --rm "$STEAMCMD_IMAGE" +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit

run_check "steamcmd-upstream-app-info" "Try SteamCMD app info for AppID 443030 with upstream steamcmd/steamcmd:ubuntu-24." "true" "true" \
    docker run --rm "$STEAMCMD_IMAGE" +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +app_info_print "$APP_ID" +quit

if [[ "$SKIP_HOST_NETWORK" != "true" ]]; then
    if docker network inspect host >/dev/null 2>&1 && docker run --rm --network host busybox:1.36 true >/dev/null 2>&1; then
        run_check "steamcmd-upstream-login-host-network" "Try upstream SteamCMD anonymous login using Docker host networking." "true" "true" \
            docker run --rm --network host "$STEAMCMD_IMAGE" +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit
    else
        add_skip "steamcmd-upstream-login-host-network" "Docker host networking is not available or not enabled."
    fi
fi

{
    printf '\nInconclusiveCount=%s\n' "$INCONCLUSIVE_COUNT"
    printf 'SteamFailureCount=%s\n' "$STEAM_FAILURE_COUNT"
    printf 'FailureCount=%s\n' "$FAILURE_COUNT"
} >> "$SUMMARY_PATH"

printf '\nSummary: inconclusive=%s steam_failures=%s failures=%s\n' "$INCONCLUSIVE_COUNT" "$STEAM_FAILURE_COUNT" "$FAILURE_COUNT"
printf 'Summary file: %s\n' "$SUMMARY_PATH"

if [[ "$FAILURE_COUNT" -gt 0 ]]; then
    exit 1
fi

if [[ "$STRICT_STEAM_FAILURES" == "true" && "$STEAM_FAILURE_COUNT" -gt 0 ]]; then
    exit 2
fi

exit 0
