# Configuration

Edit `.env` from `.env.example`, then restart the container.

Boolean variables accept `true/false`, `yes/no`, and `1/0`.

Passwords are never printed in logs. Logs only report whether each password is set or empty.

## Runtime Variables

| Variable | Default | Description |
| --- | --- | --- |
| `TZ` | `America/New_York` | Container timezone. |
| `PUID` | `1000` | UID for the runtime server user. |
| `PGID` | `1000` | GID for the runtime server group. |

## Server Variables

| Variable | Default | Target |
| --- | --- | --- |
| `SERVER_NAME` | `Conan Exiles Server` | `ServerSettings.ini` / `ServerSettings.ServerName` |
| `SERVER_PASSWORD` | empty | `ServerSettings.ini` / `ServerSettings.ServerPassword` |
| `ADMIN_PASSWORD` | empty | `ServerSettings.ini` / `ServerSettings.AdminPassword` |
| `MAX_PLAYERS` | `40` | `ServerSettings.ini` / `ServerSettings.MaxPlayers`; `Game.ini` / `/Script/Engine.GameSession.MaxPlayers` |
| `GAME_PORT` | `7777` | `ServerSettings.ini` / `ServerSettings.Port`; `Engine.ini` / `URL.Port` |
| `PINGER_PORT` | `7778` | `ServerSettings.ini` / `ServerSettings.PingerPort` |
| `QUERY_PORT` | `27015` | `ServerSettings.ini` / `ServerSettings.QueryPort`; `Engine.ini` / `OnlineSubsystemSteam.GameServerQueryPort` |
| `RCON_ENABLED` | `true` | `ServerSettings.ini` / `ServerSettings.RconEnabled` |
| `RCON_PORT` | `25575` | `ServerSettings.ini` / `ServerSettings.RconPort` |
| `RCON_PASSWORD` | empty | `ServerSettings.ini` / `ServerSettings.RconPassword` |

These config paths are implementation targets and must be checked against the real AppID `443030` server files before the MVP is marked complete.

## Update Variables

| Variable | Default | Description |
| --- | --- | --- |
| `UPDATE_SERVER_ON_START` | `true` | Runs the selected server download backend before launch. |
| `VALIDATE_SERVER_FILES` | `false` | Adds validation when the selected backend supports it. |
| `DOWNLOAD_BACKEND` | `steamcmd` | Server download backend. Supported values are `steamcmd`, `depotdownloader`, and `auto`. |
| `AUTO_GAME_UPDATE` | `false` | Planned only; no background loop in MVP. |
| `AUTO_GAME_UPDATE_INTERVAL_MINUTES` | `360` | Planned loop interval. |
| `UPDATE_MODS_ON_START` | `true` | Downloads/updates Workshop mods before launch. |
| `AUTO_MOD_UPDATE` | `false` | Planned only; no background loop in MVP. |

`steamcmd` remains the default. `depotdownloader` uses the pinned image-installed DepotDownloader binary. `auto` tries SteamCMD first, logs the SteamCMD failure path, then tries DepotDownloader. It does not silently hide the first backend failure.

DepotDownloader support is currently for server AppID `443030` only. Workshop mods still use SteamCMD.

## Mod Variables

| Variable | Default | Description |
| --- | --- | --- |
| `WORKSHOP_MOD_IDS` | empty | Comma-separated ordered Workshop IDs. |
| `PRUNE_REMOVED_MODS` | `true` | Deletes downloaded Workshop directories no longer listed. |

## Backup Variables

| Variable | Default | Description |
| --- | --- | --- |
| `BACKUP_LOCATION` | `/serverdata/backups` | Backup archive directory. |
| `BACKUP_ON_START` | `true` | Backs up before startup update/mod operations when data exists. |
| `BACKUP_ON_STOP` | `false` | Backs up during graceful shutdown. |
| `BACKUP_RETENTION_DAYS` | `14` | Deletes older backups when positive. `0` disables cleanup. |

## Launch Variables

| Variable | Default | Description |
| --- | --- | --- |
| `EXTRA_ARGS` | empty | Extra launch arguments split on spaces. Do not put secrets here. |
