# ConanExilesContainer

Docker container project for running a Conan Exiles Enhanced dedicated server from Steam dedicated server AppID `443030`.

Current status: initial MVP scaffold with local image/script validation. The container uses SteamCMD, requests native Linux server files, and fails clearly if Steam only provides Windows server files. Wine is not included in the MVP.

Local AppID download status: blocked on this Docker Desktop host because SteamCMD anonymous login fails with `FAILED (No Connection)`, including in the upstream SteamCMD image. External SteamDB metadata currently lists Linux support, depot `443032`, and Linux executable `ConanSandbox\Binaries\Linux\ConanSandboxServer`, but this still needs verification from a completed local download.

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

`UPDATE_SERVER_ON_START=true` runs SteamCMD on container startup. If `UPDATE_SERVER_ON_START=false` and the app manifest already exists, update is skipped. If server files do not exist, the container downloads them even when the update flag is false.

`VALIDATE_SERVER_FILES=true` adds SteamCMD validation.

`AUTO_GAME_UPDATE` and `AUTO_MOD_UPDATE` are planned variables only in the MVP. The container logs that they are not active if enabled.

## Mods

Set `WORKSHOP_MOD_IDS` to a comma-separated ordered list:

```env
WORKSHOP_MOD_IDS=123456789,987654321
```

The container downloads each mod, finds `.pak` files, and writes `ConanSandbox/Mods/modlist.txt` in the same order. Removed downloaded mods are deleted only when `PRUNE_REMOVED_MODS=true`.

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

The local Codex host has public internet access but no LAN access. Do not use it for LAN, Rocky Linux, or Unraid connectivity tests.

See `docs/TROUBLESHOOTING_STEAMCMD.md`.

## Rocky Linux

Rocky Linux testing starts after local Docker Desktop works. Clone or copy the repo to the Rocky Linux host, use the same compose file, and map volumes to normal host paths.

See `docs/ROCKY_LINUX.md`.

## GitHub Repository

Repository: `https://github.com/bryans1981/ConanExilesContainer`

Default visibility is private. GitHub creation, remote setup, commit, and push should be automated when authenticated access exists. Do not make the repository public without explicit approval.

## Known Limitations

- Native Linux server availability for AppID `443030` still needs proof from a completed Docker first boot on a host where SteamCMD anonymous login works.
- Config key mapping and modlist behavior must be verified against downloaded server files.
- Wine fallback is intentionally absent.
- Full WebGUI is planned for Phase 2 only.
