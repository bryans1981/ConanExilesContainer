# ConanExilesContainer

## Goal

Create a simple Docker container project for running a Conan Exiles Enhanced dedicated server using native Linux dedicated server software where possible. The container should automatically download, install, update, configure, and start the server so a user only needs Docker, mapped volumes, required ports, and environment variables.

## Repository

- Repo name: `ConanExilesContainer`
- Default visibility: private
- Expected remote: `https://github.com/bryans1981/ConanExilesContainer`
- GitHub creation, remote setup, commit, and push should be automated when authenticated access exists.
- Do not make the repository public unless the user explicitly approves public visibility.

## Development Target Order

1. Docker Desktop local
2. Rocky Linux Docker host
3. Generic Docker deployment

## MVP Definition

The MVP succeeds when a user can clone the repository, run `docker compose up -d` locally through Docker Desktop, and get the dedicated server installed, configured, optionally modded, backed up, and running without manually installing server files or Workshop mods.

Current MVP status: scaffold and local image validation are complete, but MVP success is not claimed. Docker Desktop on this host cannot currently complete Steam anonymous login, so AppID `443030` download and native executable verification remain blocked.

## Required Features

- SteamCMD install/update for AppID `443030`.
- Native Linux server executable detection.
- Clear failure if no native Linux executable exists.
- Persistent server files, Steam/cache, config, logs, backups, and mod data through mapped volumes.
- Environment-driven common server settings.
- Workshop mod download/update from ordered comma-separated IDs.
- Conan mod list generation in the configured order.
- Optional pruning of removed Workshop mod downloads.
- Timestamped backups before risky startup update/mod operations when enabled.
- Graceful shutdown handling.
- Docker healthcheck based on the running server process.

## Out Of Scope For MVP

- Full WebGUI.
- Wine fallback.
- Background auto game update loop.
- Background auto mod update loop.
- Public GitHub repository visibility.

## Verified So Far

- `docker compose config` succeeds.
- Bash syntax checks pass for all scripts.
- `docker compose build` succeeds.
- SteamCMD starts successfully when using the seeded non-root Steam home under `/serverdata/steam`.
- Config generation creates persistent `LinuxServer` config files and applies environment values without logging passwords.
- Empty `WORKSHOP_MOD_IDS` creates an empty active mod list.
- Backup creation works.
- Server start fails loudly when no native Linux executable exists.

## Current Blocker

SteamCMD anonymous login fails from Docker Desktop on this host before AppID `443030` can be downloaded:

```text
Connecting anonymously to Steam Public...
FAILED (No Connection)
```

The same failure happens with the upstream `steamcmd/steamcmd:ubuntu-24` image, including with Docker host networking, so this is currently treated as a local Steam connectivity blocker rather than a project-image failure.

External SteamDB metadata, last checked June 23, 2026, lists AppID `443030` as supporting Windows and Linux, with Linux depot `443032` and Linux launch executable `ConanSandbox\Binaries\Linux\ConanSandboxServer`. This is useful orientation only; it does not replace local verification from downloaded files.

References:

- https://steamdb.info/app/443030/depots/
- https://steamdb.info/app/443030/config/

## Environment Variables

| Variable | Default | Purpose | Current file/key target |
| --- | --- | --- | --- |
| `TZ` | `America/New_York` | Container timezone | Runtime environment |
| `PUID` | `1000` | Runtime user ID | Linux user setup |
| `PGID` | `1000` | Runtime group ID | Linux group setup |
| `SERVER_NAME` | `Conan Exiles Server` | Server display name | `ServerSettings.ini` / `ServerSettings.ServerName` |
| `SERVER_PASSWORD` | empty | Server join password | `ServerSettings.ini` / `ServerSettings.ServerPassword` |
| `ADMIN_PASSWORD` | empty | Admin password | `ServerSettings.ini` / `ServerSettings.AdminPassword` |
| `MAX_PLAYERS` | `40` | Player limit | `ServerSettings.ini` / `ServerSettings.MaxPlayers`; `Game.ini` / `/Script/Engine.GameSession.MaxPlayers` |
| `GAME_PORT` | `7777` | Game UDP port | `ServerSettings.ini` / `ServerSettings.Port`; `Engine.ini` / `URL.Port` |
| `PINGER_PORT` | `7778` | Pinger UDP port | `ServerSettings.ini` / `ServerSettings.PingerPort` |
| `QUERY_PORT` | `27015` | Steam query UDP port | `ServerSettings.ini` / `ServerSettings.QueryPort`; `Engine.ini` / `OnlineSubsystemSteam.GameServerQueryPort` |
| `RCON_ENABLED` | `true` | RCON toggle | `ServerSettings.ini` / `ServerSettings.RconEnabled` |
| `RCON_PORT` | `25575` | RCON TCP port | `ServerSettings.ini` / `ServerSettings.RconPort` |
| `RCON_PASSWORD` | empty | RCON password | `ServerSettings.ini` / `ServerSettings.RconPassword` |
| `UPDATE_SERVER_ON_START` | `true` | Run SteamCMD update on startup | Startup behavior |
| `VALIDATE_SERVER_FILES` | `false` | Add SteamCMD validation | SteamCMD update behavior |
| `AUTO_GAME_UPDATE` | `false` | Planned background update loop | Not active in MVP |
| `AUTO_GAME_UPDATE_INTERVAL_MINUTES` | `360` | Planned loop interval | Not active in MVP |
| `UPDATE_MODS_ON_START` | `true` | Download/update mods on startup | Startup behavior |
| `AUTO_MOD_UPDATE` | `false` | Planned background mod update loop | Not active in MVP |
| `WORKSHOP_MOD_IDS` | empty | Comma-separated ordered Workshop IDs | `ConanSandbox/Mods/modlist.txt` |
| `PRUNE_REMOVED_MODS` | `true` | Remove no-longer-listed downloaded mods | Steam Workshop content directory |
| `BACKUP_LOCATION` | `/serverdata/backups` | Backup archive directory | Backup script |
| `BACKUP_ON_START` | `true` | Backup before startup update/mod operations | Backup script |
| `BACKUP_ON_STOP` | `false` | Backup during graceful shutdown | Entrypoint shutdown |
| `BACKUP_RETENTION_DAYS` | `14` | Delete older backup archives when positive | Backup script |
| `EXTRA_ARGS` | empty | Extra server launch args, split on spaces | Launch command |

Config key paths above are the initial implementation targets and must be verified against the actual downloaded native server files before claiming MVP success.

## Ports

- `7777/udp`: game port
- `7778/udp`: pinger port
- `27015/udp`: Steam query port
- `25575/tcp`: RCON port when enabled
- `8080/tcp`: reserved for optional future WebGUI only

## Volumes

Local development volumes:

- `./data/serverfiles:/serverdata/serverfiles`
- `./data/steam:/serverdata/steam`
- `./data/config:/serverdata/config`
- `./data/logs:/serverdata/logs`
- `./data/backups:/serverdata/backups`

## Backup Behavior

Backups are timestamped `.tar.gz` archives in `BACKUP_LOCATION`. They include persistent config, `ConanSandbox/Saved`, active mod list files, and the Steam app manifest when present. Retention cleanup only runs when `BACKUP_RETENTION_DAYS` is a positive number and logs each removed archive.

## Workshop Mod Behavior

`WORKSHOP_MOD_IDS` is parsed as a comma-separated ordered list. Each ID is downloaded with SteamCMD using Workshop app ID `440900`. The generated mod list is written to `ConanSandbox/Mods/modlist.txt` in the same order. Removed downloads are pruned only when `PRUNE_REMOVED_MODS=true`.

Workshop app ID and modlist path must be validated with real downloaded server/mod files during Docker Desktop testing.

## Testing Requirements

- Build the image locally.
- Run clean first boot with empty `./data` folders.
- Confirm server files download.
- Confirm native Linux executable exists.
- Confirm config files are created and env values apply.
- Confirm server process starts and stops gracefully.
- Confirm restart does not wipe saves/config.
- Confirm update toggle behavior.
- Confirm Workshop mod download, ordering, removal, pruning, and backup behavior.
- Confirm logs do not expose passwords.
- Confirm project-control docs are current.

## Phase 2 WebGUI Notes

The WebGUI is planned only. See `docs/WEBGUI_PHASE_2.md`.
