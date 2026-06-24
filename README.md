# ConanExilesContainer

Docker container project for running a Conan Exiles Enhanced dedicated server from Steam dedicated server AppID `443030`.

Current status: local Docker Desktop MVP flow is verified with the default DepotDownloader backend. A clean disposable compose run downloaded AppID `443030`, generated config, downloaded Workshop item `3720546346`, wrote `ConanSandbox/Mods/modlist.txt`, started through the native Linux launcher to `StartPlay`, shut down gracefully, restarted without wiping config/modlist, created backups, and did not print test password values in retained logs. Wine is not included in the MVP.

SteamCMD status: Docker Desktop `4.72.0` / Engine `29.4.2` blocks Linux SteamCMD under the default builtin seccomp profile. Windows host SteamCMD works, and Linux SteamCMD works when run with diagnostic `seccomp=unconfined`, so this is a Docker security-profile compatibility issue, not a general Steam or host internet failure. The normal compose flow avoids that blocker by using DepotDownloader for server and Workshop downloads by default.

## Requirements

- Docker Desktop for local development, or Docker Engine on Linux.
- UDP ports `7777`, `7778`, and `27015` available.
- TCP port `25575` available if RCON is enabled.
- Enough disk space for the server files, Workshop mods, saves, logs, and backups.

## Quick Start

```powershell
Copy-Item .env.example .env
docker compose build
docker compose up -d
docker compose logs -f
```

The first boot downloads or updates the dedicated server, creates missing config files, applies environment settings, updates configured Workshop mods, creates backups when enabled, and starts the server.

DepotDownloader is the default downloader for both server files and Workshop mods:

```env
DOWNLOAD_BACKEND=depotdownloader
MOD_DOWNLOAD_BACKEND=depotdownloader
```

SteamCMD remains available for hosts where it works:

```env
DOWNLOAD_BACKEND=steamcmd
MOD_DOWNLOAD_BACKEND=steamcmd
```

For diagnostics or an explicit fallback test, set either backend to `auto`. `auto` tries DepotDownloader first, then logs any failure before trying SteamCMD. It is not silent fallback.

## Ports

- `7777/udp`: game traffic
- `7778/udp`: pinger
- `27015/udp`: Steam query
- `25575/tcp`: RCON
- `8080/tcp`: reserved for future Phase 2 WebGUI; not used by the MVP

## Volumes

The compose file maps:

- `./data/serverfiles:/serverdata/serverfiles`
- `./data/steam:/serverdata/steam`
- `./data/config:/serverdata/config`
- `./data/logs:/serverdata/logs`
- `./data/backups:/serverdata/backups`

Do not delete `./data` unless you intend to remove local server files, saves, config, logs, Steam cache, mods, and backups.

## Configuration

Copy `.env.example` to `.env` and edit values before first boot. Passwords are never printed in logs; logs only report whether password variables are set or empty.

See `docs/CONFIG.md` for the full variable map.

For the Conan server browser region, `SERVER_REGION=1` sets North America/America. The verified launcher mapping is `0` Europe, `1` North America, `2` Asia, `3` Australia, `4` South America, and `5` Japan.

If direct LAN connect works but the server does not require the expected password, check the effective env and active Conan config without printing secrets:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\local-env-effective-diagnostics.ps1 -EnvFile .env.local-live
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\conan-config-effective-diagnostics.ps1 -EnvFile .env.local-live
```

## Updates

`UPDATE_SERVER_ON_START=true` runs the selected download backend on container startup. If `UPDATE_SERVER_ON_START=false` and existing server files are detected, update is skipped. If server files do not exist, the container downloads them even when the update flag is false.

`VALIDATE_SERVER_FILES=true` adds backend validation when supported.

`AUTO_GAME_UPDATE` and `AUTO_MOD_UPDATE` are planned variables only in the MVP. The container logs that they are not active if enabled.

## Mods

Set `WORKSHOP_MOD_IDS` to a comma-separated ordered list:

```env
WORKSHOP_MOD_IDS=123456789,987654321
```

The container downloads each mod, finds `.pak` files, and writes `ConanSandbox/Mods/modlist.txt` in the same order. Removed downloaded mods are deleted only when `PRUNE_REMOVED_MODS=true`.

`MOD_DOWNLOAD_BACKEND=depotdownloader` is the default. DepotDownloader Workshop download was verified under normal Docker security with item `3720546346`, producing `HEUnlimitedWeight.pak`. A clean compose e2e run generated `ConanSandbox/Mods/modlist.txt` and reached `StartPlay` with that modlist in place.

See `docs/MODS.md`.

## Backups

Backups are timestamped `.tar.gz` archives in `BACKUP_LOCATION`, defaulting to `/serverdata/backups`. They include config, saves, mod list files, and the Steam app manifest when present.

See `docs/BACKUPS.md` for restore basics.

## Local Docker Desktop Testing

Start from the repo root:

```powershell
docker compose build
docker compose up
```

Watch logs for `StartPlay` during launch. The local default-flow smoke test has proven download, config, launch, graceful shutdown, restart persistence, backups, and single-mod modlist handling on this Docker Desktop host.

See `docs/LOCAL_DOCKER_DESKTOP.md`.

## Local Live Client Testing

For a real local game-client login test, use an ignored local env file and the live-test workflow:

```powershell
docker compose --env-file .env.local-live up -d --build
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\local-live-status.ps1 -EnvFile .env.local-live
```

See `docs/LOCAL_LIVE_TEST.md` for the server-browser name, direct-connect options, log checks, stop/restart commands, and what client result to report back. Do not commit `.env.local-live` or real local test passwords.

If a Docker Desktop server reaches `StartPlay` but does not appear in the in-game browser from another LAN client, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\local-lan-server-diagnostics.ps1 -EnvFile .env.local-live
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\windows-firewall-conan-rules.ps1 -EnvFile .env.local-live
```

See `docs/TROUBLESHOOTING_SERVER_LISTING.md`. The firewall helper is check-only unless run with `-Apply` from an Administrator PowerShell.

## Troubleshooting

If SteamCMD anonymous login fails with `FAILED (No Connection)`, run the repeatable diagnostics:

```powershell
.\tests\steamcmd-connectivity.ps1
```

For Docker seccomp/security A/B checks:

```powershell
.\tests\windows-steamcmd-comparison.ps1
.\tests\steamcmd-security-diagnostics.ps1
```

To compare against the pinned DepotDownloader backend:

```powershell
.\tests\depotdownloader-connectivity.ps1
```

The local Codex host has public internet access but no LAN access. Do not use it for LAN, Rocky Linux, or Unraid connectivity tests.

See `docs/TROUBLESHOOTING_STEAMCMD.md`.

Diagnostic-only SteamCMD seccomp override:

```powershell
docker compose -f docker-compose.yml -f docker-compose.steamcmd-unconfined.diagnostic.yml up
```

This is less secure than default Docker isolation and is not recommended for normal use. Prefer the default DepotDownloader backend or upgrade Docker Engine/Desktop to a fixed version if you need SteamCMD.

## Rocky Linux

Rocky Linux testing starts after local Docker Desktop works. Clone or copy the repo to the Rocky Linux host, use the same compose file, and map volumes to normal host paths.

See `docs/ROCKY_LINUX.md`.

## GitHub Repository

Repository: `https://github.com/bryans1981/ConanExilesContainer`

Default visibility is private. GitHub creation, remote setup, commit, and push should be automated when authenticated access exists. Do not make the repository public without explicit approval.

## Known Limitations

- SteamCMD is blocked on Docker Engine `29.4.2` builtin seccomp unless the diagnostic unconfined override is used.
- Multi-mod ordering, pruning behavior, and long-running public-server behavior still need broader testing beyond the single-mod clean e2e proof.
- Wine fallback is intentionally absent.
- Full WebGUI is planned for Phase 2 only.
