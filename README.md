# ConanExilesContainer

Docker container project for running a Conan Exiles Enhanced dedicated server from Steam dedicated server AppID `443030`.

Current status: initial MVP scaffold with local image/script validation. The container uses SteamCMD by default, requests native Linux server files, and fails clearly if Steam only provides Windows server files. Wine is not included in the MVP.

Local AppID download status: Docker Desktop `4.72.0` / Engine `29.4.2` blocks Linux SteamCMD under the default builtin seccomp profile. Windows host SteamCMD works, and Linux SteamCMD works when run with diagnostic `seccomp=unconfined`, so this is a Docker security-profile compatibility issue, not a general Steam or host internet failure. A controlled DepotDownloader diagnostic run on June 23, 2026 did download AppID `443030`, verified native launcher `ConanSandboxServer.sh`, verified native executable `ConanSandbox/Binaries/Linux/ConanSandboxServer-Linux-Shipping`, and reached a bounded server launch/config probe. Full MVP success is still not claimed because full first boot and live Workshop mod loading remain unverified end to end.

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

SteamCMD remains the default downloader variable:

```env
DOWNLOAD_BACKEND=steamcmd
```

For normal local testing on Docker Engine `29.4.2`, set:

```env
DOWNLOAD_BACKEND=depotdownloader
```

For diagnostics or an explicit fallback test, set `DOWNLOAD_BACKEND=auto`. `auto` logs the SteamCMD failure path before trying DepotDownloader; it is not silent fallback.

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

On Docker Engine `29.4.2`, SteamCMD Workshop download also requires the same seccomp workaround or a Docker upgrade. A single small Workshop mod download was verified with the diagnostic unconfined override, but live server loading is not yet verified.

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

Watch logs to verify whether AppID `443030` provides native Linux server files. The MVP cannot be claimed successful until local Docker Desktop proves download, config, launch, graceful shutdown, restart persistence, backups, and mod handling.

See `docs/LOCAL_DOCKER_DESKTOP.md`.

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

This is less secure than default Docker isolation and is not recommended for normal use. Prefer upgrading Docker Engine/Desktop to a fixed version or using `DOWNLOAD_BACKEND=depotdownloader`.

## Rocky Linux

Rocky Linux testing starts after local Docker Desktop works. Clone or copy the repo to the Rocky Linux host, use the same compose file, and map volumes to normal host paths.

See `docs/ROCKY_LINUX.md`.

## GitHub Repository

Repository: `https://github.com/bryans1981/ConanExilesContainer`

Default visibility is private. GitHub creation, remote setup, commit, and push should be automated when authenticated access exists. Do not make the repository public without explicit approval.

## Known Limitations

- SteamCMD default download path is blocked on Docker Engine `29.4.2` builtin seccomp.
- Workshop single-mod download and `.pak` discovery were verified under diagnostic `seccomp=unconfined`; live server mod loading, multi-mod ordering, pruning, and backup interaction still need verification.
- Wine fallback is intentionally absent.
- Full WebGUI is planned for Phase 2 only.
