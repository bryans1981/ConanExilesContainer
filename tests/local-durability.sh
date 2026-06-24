#!/usr/bin/env bash

set -Eeuo pipefail

env_file=".env.local-live"
quick=false
keep_running=false
skip_client_reminder=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file|-e)
      env_file="${2:?missing value for $1}"
      shift 2
      ;;
    --quick)
      quick=true
      shift
      ;;
    --keep-running)
      keep_running=true
      shift
      ;;
    --skip-client-reminder)
      skip_client_reminder=true
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

failures=0
warnings=0
service="conan"
ready_timeout=600
[[ "$quick" == "true" ]] && ready_timeout=300

result() { printf '%s %s - %s\n' "$1" "$2" "$3"; }
pass() { result PASS "$1" "$2"; }
info() { result INFO "$1" "$2"; }
warn() { warnings=$((warnings + 1)); result WARN "$1" "$2"; }
fail() { failures=$((failures + 1)); result FAIL "$1" "$2"; }

env_value() {
  local key="$1"
  local default="${2:-}"
  local value
  value="$(awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; found=1 } END { if (!found) exit 1 }' "$env_file" 2>/dev/null || true)"
  [[ -n "$value" ]] && printf '%s' "$value" || printf '%s' "$default"
}

truthy() {
  case "${1,,}" in
    true|yes|1|on) return 0 ;;
    *) return 1 ;;
  esac
}

container_id() {
  docker compose --env-file "$env_file" ps -q "$service" 2>/dev/null | head -n 1
}

wait_startplay() {
  local since="$1"
  local deadline=$((SECONDS + ready_timeout))
  local cid
  while (( SECONDS < deadline )); do
    cid="$(container_id || true)"
    if [[ -n "$cid" ]] && docker inspect "$cid" --format '{{.State.Running}}' 2>/dev/null | grep -q true; then
      if [[ -n "$since" ]]; then
        docker logs --since "$since" --tail 1200 "$cid" 2>/dev/null | grep -q StartPlay && { pass readiness "StartPlay marker found."; return 0; }
      else
        docker logs --tail 1200 "$cid" 2>/dev/null | grep -q StartPlay && { pass readiness "StartPlay marker found."; return 0; }
      fi
    fi
    sleep 10
  done
  fail readiness "StartPlay marker was not found within ${ready_timeout} seconds."
  return 1
}

scan_password_leaks() {
  local cid="$1"
  local found=false
  local values=()
  local value
  for key in SERVER_PASSWORD ADMIN_PASSWORD RCON_PASSWORD; do
    value="$(env_value "$key" "")"
    [[ -n "$value" ]] && values+=("$value")
  done
  if [[ "${#values[@]}" -eq 0 ]]; then
    warn password-leak-scan "No non-empty password values were present in the env file."
    return 0
  fi

  for value in "${values[@]}"; do
    docker logs --tail 1200 "$cid" 2>/dev/null | grep -Fq "$value" && found=true
    if [[ -d data/logs ]]; then
      grep -RIl --exclude-dir=.git -- "$value" data/logs >/dev/null 2>&1 && found=true
    fi
    git grep -Il -- "$value" >/dev/null 2>&1 && found=true
  done

  if [[ "$found" == "true" ]]; then
    fail password-leak-scan "A password value from the env file appeared in Docker logs, retained logs, or tracked files."
  else
    pass password-leak-scan "No env password values found in Docker logs, retained logs, or tracked files."
  fi
}

echo "Conan local durability test"
echo

command -v docker >/dev/null 2>&1 && pass docker.version "Docker CLI found." || { fail docker.version "Docker CLI missing."; exit 1; }
docker compose config --quiet >/dev/null 2>&1 && pass compose.config.default "Command succeeded." || fail compose.config.default "Command failed."
[[ -f "$env_file" ]] && pass env-file "Using $env_file" || { fail env-file "Missing env file: $env_file"; exit 1; }
docker compose --env-file "$env_file" config --quiet >/dev/null 2>&1 && pass compose.config.env-file "Command succeeded." || fail compose.config.env-file "Command failed."

cid="$(container_id || true)"
initial_running=false
if [[ -n "$cid" ]] && docker inspect "$cid" --format '{{.State.Running}}' 2>/dev/null | grep -q true; then
  initial_running=true
  pass container.status.before "Running."
else
  warn container.status.before "Service is not running; starting it for durability test."
  docker compose --env-file "$env_file" up -d >/dev/null
fi

cid="$(container_id)"
[[ -n "$cid" ]] && pass container "${cid:0:12}" || { fail container "Could not determine compose container ID."; exit 1; }
wait_startplay "" || true

active_path="$(docker exec "$cid" bash -lc 'readlink -f /serverdata/serverfiles/ConanSandbox/Saved/Config/LinuxServer 2>/dev/null || true')"
[[ -n "$active_path" ]] && pass active-config.container-path "$active_path" || fail active-config.container-path "Could not resolve active LinuxServer config path."
[[ -d data/config/ConanSandbox/Saved/Config/LinuxServer ]] && pass active-config.host-path "data/config/ConanSandbox/Saved/Config/LinuxServer" || fail active-config.host-path "Persistent config directory is missing."

server_name="$(env_value SERVER_NAME "Conan Exiles Server")"
region="$(env_value SERVER_REGION America)"
[[ "$region" == "America" || "$region" == "NorthAmerica" || "$region" == "1" ]] && expected_region=1 || expected_region="$region"
grep -Fq "ServerName=$server_name" data/config/ConanSandbox/Saved/Config/LinuxServer/Engine.ini && pass config.SERVER_NAME "Applied." || fail config.SERVER_NAME "Not found in Engine.ini."
grep -Fq "serverRegion=$expected_region" data/config/ConanSandbox/Saved/Config/LinuxServer/ServerSettings.ini && pass config.SERVER_REGION "serverRegion=$expected_region" || fail config.SERVER_REGION "Expected serverRegion=$expected_region."
grep -Eq '^ServerPassword=.+$' data/config/ConanSandbox/Saved/Config/LinuxServer/Engine.ini && pass config.SERVER_PASSWORD "<set>" || fail config.SERVER_PASSWORD "Missing or blank."
grep -Eq '^AdminPassword=.+$' data/config/ConanSandbox/Saved/Config/LinuxServer/ServerSettings.ini && pass config.ADMIN_PASSWORD "<set>" || fail config.ADMIN_PASSWORD "Missing or blank."

for port in "$(env_value GAME_PORT 7777)/udp" "$(env_value PINGER_PORT 7778)/udp" "$(env_value QUERY_PORT 27015)/udp"; do
  docker inspect "$cid" --format '{{json .NetworkSettings.Ports}}' | grep -Fq "\"$port\"" && pass published-port "$port" || fail published-port "$port is not published."
done
if truthy "$(env_value RCON_ENABLED false)"; then
  rcon_port="$(env_value RCON_PORT 25575)/tcp"
  docker inspect "$cid" --format '{{json .NetworkSettings.Ports}}' | grep -Fq "\"$rcon_port\"" && pass published-port "$rcon_port" || fail published-port "$rcon_port is not published."
fi

config_files_before="$(find data/config -type f 2>/dev/null | wc -l | tr -d ' ')"
saved_files_before="$(find data/serverfiles/ConanSandbox/Saved -type f 2>/dev/null | wc -l | tr -d ' ')"
backup_count_before="$(find data/backups -maxdepth 1 -type f -name 'conan-backup-*.tar.gz' 2>/dev/null | wc -l | tr -d ' ')"
docker compose --env-file "$env_file" exec -T "$service" /scripts/backup.sh durability >/dev/null 2>&1 && pass backup.command "Command succeeded." || fail backup.command "Command failed."
backup_count_after="$(find data/backups -maxdepth 1 -type f -name 'conan-backup-*.tar.gz' 2>/dev/null | wc -l | tr -d ' ')"
(( backup_count_after > backup_count_before )) && pass backup.create "A new backup archive was created." || fail backup.create "No new backup archive was detected."

docker exec "$cid" bash -lc 'test -f /serverdata/serverfiles/ConanSandbox/Mods/modlist.txt && while IFS= read -r pak; do [ -z "$pak" ] || [ -f "$pak" ] || exit 3; done < /serverdata/serverfiles/ConanSandbox/Mods/modlist.txt' && pass modlist "Path exists and entries are valid." || fail modlist "Missing or invalid modlist."

info restart "Stopping compose service gracefully."
docker compose --env-file "$env_file" stop -t 120 "$service" >/dev/null
restart_since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
info restart "Starting compose service again."
docker compose --env-file "$env_file" start "$service" >/dev/null
wait_startplay "$restart_since" || true

config_files_after="$(find data/config -type f 2>/dev/null | wc -l | tr -d ' ')"
saved_files_after="$(find data/serverfiles/ConanSandbox/Saved -type f 2>/dev/null | wc -l | tr -d ' ')"
(( config_files_after >= config_files_before )) && pass persist.config.after "files=$config_files_after" || fail persist.config.after "Config directory did not persist as expected."
(( saved_files_after >= saved_files_before )) && pass persist.saves.after "files=$saved_files_after" || fail persist.saves.after "Saved directory did not persist as expected."

cid="$(container_id)"
scan_password_leaks "$cid"

if [[ "$keep_running" == "false" && "$initial_running" == "false" ]]; then
  info final-state "Initial state was not running; stopping service after test."
  docker compose --env-file "$env_file" stop -t 120 "$service" >/dev/null
else
  pass final-state "Service left running for continued local/client testing."
fi

if [[ "$skip_client_reminder" == "false" ]]; then
  echo
  echo "Reminder: final server-browser, password, admin-password, region, and login claims still require a real Conan Exiles client check."
fi

echo
echo "Summary: failures=$failures warnings=$warnings"
(( failures == 0 ))
