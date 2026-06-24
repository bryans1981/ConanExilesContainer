# ConanExilesContainer

Docker container project for a Conan Exiles dedicated server using native Linux server files from Steam AppID `443030`.

## Overview

This repository builds a Docker image that downloads, configures, backs up, optionally mods, and starts a Conan Exiles server. 

## Features

- Builds an Ubuntu-based Conan Exiles server image.
- Downloads/updates server files with DepotDownloader, SteamCMD, or explicit `auto` fallback.
- Generates and updates persistent Conan config.
- Supports ordered Workshop mod downloads and `ConanSandbox/Mods/modlist.txt`.
- Creates timestamped backups for config, saves, mod state, and manifest data.
- Preserves server files, Steam cache, config, logs, backups, and saves through bind-mounted volumes.
- Includes focused diagnostics for local live testing, Docker Desktop networking, SteamCMD, DepotDownloader, and Windows Firewall.

## Quick Start

The committed `.env` contains safe defaults only. Edit it or override values through Docker Compose, Docker, Unraid, or your host environment. Put real local passwords and live test values in ignored files such as `.env.local-live`, not in committed files.

```powershell
docker compose build
docker compose up -d
docker compose logs -f conan
```

First startup downloads or updates the server, applies config, updates listed mods, creates backups when enabled, and launches the server.

## Docker Compose

`docker-compose.yml` is the recommended starting point:

```yaml
services:
  conan:
    build:
      context: .
    image: conan-exiles-container:local
    container_name: conan-exiles-container
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "7777:7777/udp"
      - "7778:7778/udp"
      - "27015:27015/udp"
      - "25575:25575/tcp"
    volumes:
      - ./data/serverfiles:/serverdata/serverfiles
      - ./data/steam:/serverdata/steam
      - ./data/config:/serverdata/config
      - ./data/logs:/serverdata/logs
      - ./data/backups:/serverdata/backups
```

The checked-in compose file already reads `.env` through Compose variable substitution, so `docker compose up -d` is enough for the normal local flow.

## Docker Run

Build the local image first:

```powershell
docker build -t conan-exiles-container:local .
```

Then run it with the safe `.env` file or your own ignored env file:

```powershell
docker run -d --name conan-exiles-container --restart unless-stopped `
  --env-file .env `
  -p 7777:7777/udp `
  -p 7778:7778/udp `
  -p 27015:27015/udp `
  -p 25575:25575/tcp `
  -v ${PWD}/data/serverfiles:/serverdata/serverfiles `
  -v ${PWD}/data/steam:/serverdata/steam `
  -v ${PWD}/data/config:/serverdata/config `
  -v ${PWD}/data/logs:/serverdata/logs `
  -v ${PWD}/data/backups:/serverdata/backups `
  conan-exiles-container:local
```

## Ports

| Port | Protocol | Purpose |
| --- | --- | --- |
| `7777` | UDP | Game traffic |
| `7778` | UDP | Pinger |
| `27015` | UDP | Steam/server query |
| `25575` | TCP | RCON when enabled |
| `8080` | TCP | Reserved for future WebGUI, not active |

## Volumes

| Host path | Container path | Contents |
| --- | --- | --- |
| `./data/serverfiles` | `/serverdata/serverfiles` | Server install, saves, generated game data |
| `./data/steam` | `/serverdata/steam` | SteamCMD cache and Workshop downloads |
| `./data/config` | `/serverdata/config` | Persistent Conan config |
| `./data/logs` | `/serverdata/logs` | Container and server logs |
| `./data/backups` | `/serverdata/backups` | Backup archives |

Do not delete `./data` unless you intend to remove local server files, saves, config, logs, Steam cache, mods, and backups.

## Environment Variables

| Variable | Default | Notes |
| --- | --- | --- |
| `TZ` | `America/New_York` | Container timezone |
| `PUID` / `PGID` | `1000` / `1000` | Runtime user and group IDs |
| `SERVER_NAME` | `Conan Exiles Server` | Display name |
| `SERVER_PASSWORD` | empty | Join password; blank means no password |
| `ADMIN_PASSWORD` | empty | Admin password |
| `SERVER_REGION` | `America` | Accepts `America`, `NorthAmerica`, or numeric `0..5`; writes `serverRegion=1` for America |
| `MAX_PLAYERS` | `40` | Player limit |
| `GAME_PORT` | `7777` | Game UDP port |
| `PINGER_PORT` | `7778` | Pinger UDP port |
| `QUERY_PORT` | `27015` | Steam query UDP port |
| `RCON_ENABLED` | `false` | Enable RCON listener/settings |
| `RCON_PORT` | `25575` | RCON TCP port |
| `RCON_PASSWORD` | empty | RCON password |
| `DOWNLOAD_BACKEND` | `depotdownloader` | `depotdownloader`, `steamcmd`, or `auto` |
| `MOD_DOWNLOAD_BACKEND` | `depotdownloader` | `depotdownloader`, `steamcmd`, or `auto` |
| `UPDATE_SERVER_ON_START` | `true` | Run server update before launch |
| `VALIDATE_SERVER_FILES` | `false` | Validate files when supported |
| `UPDATE_MODS_ON_START` | `true` | Update listed Workshop mods before launch |
| `WORKSHOP_MOD_IDS` | empty | Comma-separated ordered Workshop item IDs |
| `PRUNE_REMOVED_MODS` | `true` | Remove old downloaded mods no longer listed |
| `BACKUP_ON_START` | `true` | Backup before startup update/mod operations |
| `BACKUP_ON_STOP` | `true` | Backup during graceful shutdown |
| `BACKUP_RETENTION_DAYS` | `14` | Delete older backups; `0` disables cleanup |
| `EXTRA_ARGS` | empty | Extra launch arguments; do not put secrets here |

See [docs/CONFIG.md](docs/CONFIG.md) for the full variable map and config targets.

## Mods

Set `WORKSHOP_MOD_IDS` to a comma-separated ordered list:

```env
WORKSHOP_MOD_IDS=123456789,987654321
```

The container downloads each mod, finds `.pak` files, and writes `ConanSandbox/Mods/modlist.txt` in the same order.

See [docs/MODS.md](docs/MODS.md).

## Backups

Backups are timestamped `.tar.gz` archives in `BACKUP_LOCATION`, defaulting to `/serverdata/backups`. They include config, saves, mod list files, active mod state, and the Steam app manifest when present.

See [docs/BACKUPS.md](docs/BACKUPS.md).

## Updating

`UPDATE_SERVER_ON_START=true` runs the selected backend on startup. If server files are missing, the container downloads them even when the update flag is false.