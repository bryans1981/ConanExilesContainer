#!/usr/bin/env bash

set -Eeuo pipefail

STRICT_DEPOTDOWNLOADER_FAILURES="false"
SKIP_APP_UPDATE_ATTEMPT="false"
LOG_ROOT=""

usage() {
    cat <<'EOF'
Usage: tests/depotdownloader-connectivity.sh [options]

Options:
  --log-root PATH                     Write logs under PATH.
  --strict-depotdownloader-failures   Exit nonzero when a DepotDownloader check fails.
  --skip-app-update-attempt           Skip the bounded AppID 443030 update attempt.
  -h, --help                          Show this help.
EOF
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --log-root)
            LOG_ROOT="$2"
            shift 2
            ;;
        --strict-depotdownloader-failures)
            STRICT_DEPOTDOWNLOADER_FAILURES="true"
            shift
            ;;
        --skip-app-update-attempt)
            SKIP_APP_UPDATE_ATTEMPT="true"
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
DEPOTDOWNLOADER_VERSION="${DEPOTDOWNLOADER_VERSION:-DepotDownloader_3.4.0}"
DEPOTDOWNLOADER_RELEASE_URL="${DEPOTDOWNLOADER_RELEASE_URL:-https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_3.4.0/DepotDownloader-linux-x64.zip}"

if [[ -z "$LOG_ROOT" ]]; then
    LOG_ROOT="${REPO_ROOT}/test-results/depotdownloader-connectivity/$(date -u +%Y%m%dT%H%M%SZ)-$$"
fi

mkdir -p "$LOG_ROOT"
SUMMARY_PATH="${LOG_ROOT}/summary.txt"
INCONCLUSIVE_COUNT=0
DEPOTDOWNLOADER_FAILURE_COUNT=0
FAILURE_COUNT=0

add_summary_line() {
    printf '%s\n' "$*" >> "$SUMMARY_PATH"
}

run_check() {
    local name="$1"
    local description="$2"
    local allow_inconclusive="$3"
    local depotdownloader_check="$4"
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
        if [[ "$depotdownloader_check" == "true" ]]; then
            DEPOTDOWNLOADER_FAILURE_COUNT=$((DEPOTDOWNLOADER_FAILURE_COUNT + 1))
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
DepotDownloader connectivity diagnostics
StartedUtc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
RepoRoot=${REPO_ROOT}
LogRoot=${LOG_ROOT}
AppId=${APP_ID}
DepotDownloaderVersion=${DEPOTDOWNLOADER_VERSION}

EOF

run_check "host-dns" "Resolve public hostnames from the Codex host. No LAN hosts are contacted." "true" "false" \
    bash -lc 'if command -v getent >/dev/null 2>&1; then getent hosts github.com steamcommunity.com; elif command -v nslookup >/dev/null 2>&1; then nslookup github.com && nslookup steamcommunity.com; else echo "No host DNS lookup tool found"; exit 1; fi'

run_check "host-release-https" "Fetch the pinned DepotDownloader release URL from the host." "true" "false" \
    bash -lc "if command -v curl >/dev/null 2>&1; then curl -fsSIL --max-time 30 '${DEPOTDOWNLOADER_RELEASE_URL}' >/dev/null; elif command -v wget >/dev/null 2>&1; then wget -q -T 30 -O /dev/null '${DEPOTDOWNLOADER_RELEASE_URL}'; else echo 'No host HTTPS client found'; exit 1; fi"

run_check "docker-version" "Verify Docker client/server are available." "false" "false" \
    docker version

run_check "container-release-https" "Fetch the pinned DepotDownloader release URL from a simple container." "true" "false" \
    docker run --rm curlimages/curl:8.10.1 sh -lc "curl -fsSIL --max-time 30 '${DEPOTDOWNLOADER_RELEASE_URL}' >/dev/null"

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
    run_check "depotdownloader-version" "Run the image-installed DepotDownloader binary and print version/runtime." "true" "true" \
        docker compose run --rm -v "$volume_arg" conan /opt/depotdownloader/DepotDownloader --version

    run_check "depotdownloader-app-manifest-only" "Try DepotDownloader manifest-only access for AppID 443030 using anonymous access." "true" "true" \
        docker compose run --rm -v "$volume_arg" \
            -e SERVER_DIR=/diagnostics/serverfiles \
            -e STEAM_DIR=/diagnostics/steam \
            -e LOG_DIR=/diagnostics/logs \
            conan timeout 300s gosu conan env HOME=/diagnostics/home /opt/depotdownloader/DepotDownloader \
            -app "$APP_ID" -os linux -dir /diagnostics/manifest-only -manifest-only

    if [[ "$SKIP_APP_UPDATE_ATTEMPT" != "true" ]]; then
        run_check "depotdownloader-project-app-update" "Try project update-server.sh with DOWNLOAD_BACKEND=depotdownloader using disposable diagnostic paths." "true" "true" \
            docker compose run --rm -v "$volume_arg" \
                -e DOWNLOAD_BACKEND=depotdownloader \
                -e SERVER_DIR=/diagnostics/serverfiles \
                -e STEAM_DIR=/diagnostics/steam \
                -e LOG_DIR=/diagnostics/logs \
                conan timeout 600s gosu conan env HOME=/diagnostics/home /scripts/update-server.sh
    else
        add_skip "depotdownloader-project-app-update" "Skipped by --skip-app-update-attempt."
    fi
fi

{
    printf '\nInconclusiveCount=%s\n' "$INCONCLUSIVE_COUNT"
    printf 'DepotDownloaderFailureCount=%s\n' "$DEPOTDOWNLOADER_FAILURE_COUNT"
    printf 'FailureCount=%s\n' "$FAILURE_COUNT"
} >> "$SUMMARY_PATH"

printf '\nSummary: inconclusive=%s depotdownloader_failures=%s failures=%s\n' "$INCONCLUSIVE_COUNT" "$DEPOTDOWNLOADER_FAILURE_COUNT" "$FAILURE_COUNT"
printf 'Summary file: %s\n' "$SUMMARY_PATH"

if [[ "$FAILURE_COUNT" -gt 0 ]]; then
    exit 1
fi

if [[ "$STRICT_DEPOTDOWNLOADER_FAILURES" == "true" && "$DEPOTDOWNLOADER_FAILURE_COUNT" -gt 0 ]]; then
    exit 2
fi

exit 0
