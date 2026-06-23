#!/usr/bin/env bash

set -Eeuo pipefail

STRICT_STEAM_FAILURES="false"
SKIP_APP_INFO="false"
SKIP_HOST_NETWORK="false"
SKIP_PROJECT_IMAGE="false"
LOG_ROOT=""

usage() {
    cat <<'EOF'
Usage: tests/steamcmd-security-diagnostics.sh [options]

Options:
  --log-root PATH             Write logs under PATH.
  --strict-steam-failures     Exit nonzero when a SteamCMD security check fails.
  --skip-app-info             Skip AppID 443030 app-info checks.
  --skip-host-network         Skip optional Docker host-networking check.
  --skip-project-image        Skip project image SteamCMD checks.
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
        --skip-app-info)
            SKIP_APP_INFO="true"
            shift
            ;;
        --skip-host-network)
            SKIP_HOST_NETWORK="true"
            shift
            ;;
        --skip-project-image)
            SKIP_PROJECT_IMAGE="true"
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
CUSTOM_SECCOMP_PROFILE="${REPO_ROOT}/docker/seccomp/steamcmd-diagnostic.json"

if [[ -z "$LOG_ROOT" ]]; then
    LOG_ROOT="${REPO_ROOT}/test-results/steamcmd-security-diagnostics/$(date -u +%Y%m%dT%H%M%SZ)-$$"
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

docker_steamcmd() {
    local image="$1"
    local docker_args="$2"
    local steam_command="$3"

    # shellcheck disable=SC2086
    docker run --rm ${docker_args} --entrypoint bash "$image" -lc "timeout 240s steamcmd ${steam_command}"
}

host_network_available() {
    docker network inspect host >/dev/null 2>&1 && docker run --rm --network host busybox:1.36 true >/dev/null 2>&1
}

cd "$REPO_ROOT"
cat > "$SUMMARY_PATH" <<EOF
SteamCMD Docker security diagnostics
StartedUtc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
RepoRoot=${REPO_ROOT}
LogRoot=${LOG_ROOT}
AppId=${APP_ID}
ProjectImage=${PROJECT_IMAGE}
SteamcmdImage=${STEAMCMD_IMAGE}

EOF

run_check "docker-version" "Capture Docker client, Engine, containerd, and runc versions." "false" "false" \
    docker version

run_check "docker-info" "Capture Docker Engine security options, runtime, context, proxy, and kernel details." "false" "false" \
    docker info

run_check "docker-context" "Capture current Docker context." "false" "false" \
    bash -lc 'docker context show && docker context inspect'

run_check "docker-desktop-version" "Capture Docker Desktop version if available from the Docker CLI plugin." "true" "false" \
    docker desktop version

run_check "upstream-default-login" "Upstream Linux SteamCMD anonymous login with Docker default security profile." "true" "true" \
    docker_steamcmd "$STEAMCMD_IMAGE" "" "+@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit"

run_check "upstream-unconfined-login" "Upstream Linux SteamCMD anonymous login with diagnostic seccomp=unconfined." "true" "true" \
    docker_steamcmd "$STEAMCMD_IMAGE" "--security-opt seccomp=unconfined" "+@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit"

if [[ "$SKIP_APP_INFO" != "true" ]]; then
    run_check "upstream-default-app-info" "Upstream Linux SteamCMD AppID 443030 app info with Docker default security profile." "true" "true" \
        docker_steamcmd "$STEAMCMD_IMAGE" "" "+@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +app_info_print ${APP_ID} +quit"

    run_check "upstream-unconfined-app-info" "Upstream Linux SteamCMD AppID 443030 app info with diagnostic seccomp=unconfined." "true" "true" \
        docker_steamcmd "$STEAMCMD_IMAGE" "--security-opt seccomp=unconfined" "+@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +app_info_print ${APP_ID} +quit"
else
    add_skip "upstream-app-info" "Skipped by --skip-app-info."
fi

if [[ -f "$CUSTOM_SECCOMP_PROFILE" ]]; then
    run_check "upstream-custom-seccomp-login" "Upstream Linux SteamCMD anonymous login with project custom seccomp profile." "true" "true" \
        docker_steamcmd "$STEAMCMD_IMAGE" "--security-opt seccomp=${CUSTOM_SECCOMP_PROFILE}" "+@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit"
else
    add_skip "upstream-custom-seccomp-login" "No verified custom seccomp profile exists at docker/seccomp/steamcmd-diagnostic.json."
fi

if [[ "$SKIP_PROJECT_IMAGE" != "true" ]]; then
    if docker image inspect "$PROJECT_IMAGE" >/dev/null 2>&1; then
        run_check "project-default-login" "Project image Linux SteamCMD anonymous login with Docker default security profile." "true" "true" \
            docker_steamcmd "$PROJECT_IMAGE" "" "+@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit"

        run_check "project-unconfined-login" "Project image Linux SteamCMD anonymous login with diagnostic seccomp=unconfined." "true" "true" \
            docker_steamcmd "$PROJECT_IMAGE" "--security-opt seccomp=unconfined" "+@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit"
    else
        add_skip "project-image-present" "Project image ${PROJECT_IMAGE} is not available. Run docker compose build first."
    fi
else
    add_skip "project-image-tests" "Skipped by --skip-project-image."
fi

if [[ "$SKIP_HOST_NETWORK" != "true" ]]; then
    if host_network_available; then
        run_check "upstream-host-network-login" "Upstream Linux SteamCMD anonymous login with Docker host networking and default security." "true" "true" \
            docker_steamcmd "$STEAMCMD_IMAGE" "--network host" "+@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +quit"
    else
        add_skip "upstream-host-network-login" "Docker host networking is not available or not enabled."
    fi
else
    add_skip "upstream-host-network-login" "Skipped by --skip-host-network."
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
