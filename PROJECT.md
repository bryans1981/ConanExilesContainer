# ConanExilesContainer

## Goal

Create a simple Docker container project for running a Conan Exiles Enhanced dedicated server using native Linux dedicated server software. The container should automatically download, install, update, configure, mod, back up, and start the server so a user only needs Docker, mapped volumes, required ports, and environment variables.

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

The local Codex host has public internet access but no LAN access. LAN, Rocky Linux, and Unraid connectivity tests must be run from those target hosts later.

## MVP Definition

The MVP succeeds when a user can clone the repository, run `docker compose up -d` locally through Docker Desktop, and get the dedicated server installed, configured, optionally modded, backed up, and running without manually installing server files or Workshop mods.

Current MVP status: the local Docker Desktop default-flow MVP smoke test passed on June 23, 2026 with clean disposable volumes. The test used the default DepotDownloader backend for server and Workshop downloads, downloaded real AppID `443030` Linux files, generated config, applied test server/admin/RCON password values without printing them in retained logs, downloaded Workshop item `3720546346`, generated `ConanSandbox/Mods/modlist.txt`, reached `StartPlay`, stopped gracefully, restarted, preserved config/modlist, and created backups.

Remaining validation beyond MVP smoke coverage:

- Live game-client login from the Conan Exiles client; do not claim user connection success until the user confirms it.
- Password-protected direct LAN connection from the Conan Exiles client; do not claim password protection success until the user confirms it.
- Server-browser visibility from another LAN client; do not claim listing/public registration success until the user confirms it.
- Multi-mod ordering with more than one real Workshop mod.
- Removing mod IDs and pruning old downloads.
- Longer-running public server behavior.
- Rocky Linux and Unraid deployment from those hosts.

## Required Features

- Server install/update for AppID `443030`.
- Default server download backend: `DOWNLOAD_BACKEND=depotdownloader`.
- Default Workshop mod backend: `MOD_DOWNLOAD_BACKEND=depotdownloader`.
- Explicit backend choices for `steamcmd`, `depotdownloader`, and `auto`.
- `auto` tries DepotDownloader first, then logs failure and tries SteamCMD.
- Native Linux launcher/executable detection.
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

- `docker compose config --quiet` succeeds.
- `docker compose -f docker-compose.yml config --quiet` succeeds.
- `docker compose -f docker-compose.yml -f docker-compose.steamcmd-unconfined.diagnostic.yml config --quiet` succeeds.
- Bash syntax checks pass for all scripts and Bash diagnostics.
- PowerShell parser checks pass for all PowerShell diagnostics.
- `git diff --check` passes.
- `docker compose build` succeeds.
- DepotDownloader `DepotDownloader_3.4.0` installs into the image at build time from the official SteamRE GitHub release.
- DepotDownloader anonymous manifest-only access for AppID `443030` passes.
- `DOWNLOAD_BACKEND=depotdownloader` downloads AppID `443030` Linux files.
- Verified native launcher: `ConanSandboxServer.sh`.
- Verified native executable: `ConanSandbox/Binaries/Linux/ConanSandboxServer-Linux-Shipping`.
- Config generation creates persistent `LinuxServer` config files.
- Config generation applies `SERVER_NAME`, `SERVER_PASSWORD`, `ADMIN_PASSWORD`, `MAX_PLAYERS`, ports, RCON toggle, and `RCON_PASSWORD`.
- Local live diagnostics verified that `SERVER_NAME` and `SERVER_PASSWORD` must be written to active `Engine.ini` section `[OnlineSubsystem]` for the running Linux server to consume them; the values are also mirrored to `ServerSettings.ini` for compatibility/visibility.
- Password values are redacted from project startup/config logs.
- Ignored local env files such as `.env.local-live` and `.env.test-live` are used for live testing and must not be committed.
- Empty `WORKSHOP_MOD_IDS` creates an empty active mod list.
- `MOD_DOWNLOAD_BACKEND=depotdownloader` downloads Workshop item `3720546346` under Docker default security.
- Verified Workshop `.pak`: `steamapps/workshop/content/440900/3720546346/HEUnlimitedWeight.pak`.
- The generated active mod list is `ConanSandbox/Mods/modlist.txt`.
- The generated mod list uses absolute `.pak` paths and preserves `WORKSHOP_MOD_IDS` order.
- Backup creation works.
- Graceful shutdown works.
- Restart does not wipe config or modlist.
- Server start fails loudly when no native Linux executable exists.
- SteamCMD starts successfully when using the seeded non-root Steam home under `/serverdata/steam`.
- Windows host SteamCMD at `C:\Conan Exiles Server\DedicatedServerLauncher\steamcmd.exe` can start, anonymously log in, and print AppID `443030` app info.
- Docker Engine `29.4.2` with builtin seccomp fails Linux SteamCMD login/app-info in both the project image and upstream `steamcmd/steamcmd:ubuntu-24`.
- Diagnostic `seccomp=unconfined` makes Linux SteamCMD login/app-info pass in both the project image and upstream image.
- The diagnostic compose override `docker-compose.steamcmd-unconfined.diagnostic.yml` renders successfully and is available only as a diagnostic/emergency workaround.

## Current SteamCMD Blocker

SteamCMD anonymous login fails from Docker Desktop on this host under Docker's default builtin seccomp profile:

```text
CreateBoundSocket: failed to create socket, error [no name available] (38)
Connecting anonymously to Steam Public...
FAILED (No Connection)
```

The same failure happens with the upstream `steamcmd/steamcmd:ubuntu-24` image under the default builtin seccomp profile. The same upstream image succeeds when run with `--security-opt seccomp=unconfined`, and Windows host SteamCMD succeeds directly. This is treated as a Docker Engine/Desktop `29.4.2` seccomp compatibility issue.

Current evidence isolates the problem to Docker `29.4.2` builtin seccomp behavior for Linux SteamCMD in containers. It does not indicate a general host internet, generic container internet, Docker DNS, AppID availability, native Linux file-layout failure, or project app logic failure.

Captured local Docker details:

- Docker Desktop: `4.72.0 (225998)`
- Docker Engine: `29.4.2`
- containerd: `v2.2.3`
- runc: `1.3.5`
- Docker context: `desktop-linux`
- Security options: `seccomp`, profile `builtin`

Docker's Engine 29 release notes document that `29.4.2` blocks `AF_ALG` sockets and `socketcall(2)` in the default seccomp profile and lists SteamCMD as an affected workload. Docker's `29.4.3` notes document replacing that broad `socketcall` deny with targeted LSM controls. Preferred remediation for SteamCMD users is to upgrade Docker Engine/Desktop to a version containing that fix. This project does not change the user's Docker installation automatically.

The normal compose path does not require `seccomp=unconfined` because it uses DepotDownloader by default. Keep `docker-compose.steamcmd-unconfined.diagnostic.yml` diagnostic/emergency-only because it disables Docker seccomp filtering for the Conan service.

References:

- https://docs.docker.com/engine/release-notes/29/#2942
- https://docs.docker.com/engine/release-notes/29/#2943
- https://steamdb.info/app/443030/depots/
- https://steamdb.info/app/443030/config/

## Current Local LAN Listing Status

The Docker-hosted live server starts and reaches `StartPlay` on the Windows Docker Desktop host, but browser visibility from another LAN client is not confirmed yet.

Verified on June 24, 2026:

- Docker publishes `7777/udp`, `7778/udp`, `27015/udp`, and `25575/tcp` to the Windows host.
- The Conan process listens inside the container on `7777/udp`, `7778/udp`, and `27015/udp`.
- SourceServerQueries starts on `27015`.
- The server launch command includes `-log -QueryPort=27015`.
- Windows host UDP ownership for `7777`, `7778`, and `27015` is Docker Desktop's backend process.
- No old Windows Dedicated Server Launcher, Conan, or host SteamCMD process was found holding the target ports.
- No specific Windows Firewall inbound allow rules were found for the Conan Docker-published ports.
- The server log includes `Autologin attempt failed, unable to register server!` and `SteamSockets: Disabled due to no Steam OSS running.`
- Before the config fix, generated `ServerSettings.ini` had the requested local live server name, but the Conan startup report still showed `Name=Conan Exiles Server`; after adding `Engine.ini` `[OnlineSubsystem]` name/password writes, the startup report shows `Name=WickedServerContianer`.

Use `tests/local-lan-server-diagnostics.ps1` and `tests/windows-firewall-conan-rules.ps1` for repeatable checks. Do not claim direct LAN connection or server-browser listing works until the user confirms it from the other LAN client.

## Current Local Live Config Status

The user confirmed direct LAN connection from another system to the Windows Docker host worked, but the server allowed entry without the expected server password. That proved basic LAN/game-port traffic was working and shifted the blocker to config application.

Verified on June 24, 2026 after the config fix:

- `.env.local-live` values reached Docker Compose and the container environment.
- Active config path inside the container resolved to `/serverdata/config/ConanSandbox/Saved/Config/LinuxServer`.
- `Engine.ini` section `[OnlineSubsystem]` now contains the configured server name and a non-empty server password.
- `ServerSettings.ini` section `[ServerSettings]` contains the configured server name, non-empty server password, non-empty admin password, game/pinger/query ports, and RCON settings.
- The startup report now shows `Name=WickedServerContianer`.
- `StartPlay` and SourceServerQueries on `27015` are still reached after restart.

Do not claim password protection works until the user confirms a direct LAN connection prompts for and accepts the configured local test password.

## Environment Variables

| Variable | Default | Purpose | Current file/key target |
| --- | --- | --- | --- |
| `TZ` | `America/New_York` | Container timezone | Runtime environment |
| `PUID` | `1000` | Runtime user ID | Linux user setup |
| `PGID` | `1000` | Runtime group ID | Linux group setup |
| `SERVER_NAME` | `Conan Exiles Server` | Server display name | Active: `Engine.ini` / `OnlineSubsystem.ServerName`; mirrored to `ServerSettings.ini` / `ServerSettings.ServerName` |
| `SERVER_PASSWORD` | empty | Server join password | Active: `Engine.ini` / `OnlineSubsystem.ServerPassword`; mirrored to `ServerSettings.ini` / `ServerSettings.ServerPassword` |
| `ADMIN_PASSWORD` | empty | Admin password | `ServerSettings.ini` / `ServerSettings.AdminPassword` |
| `MAX_PLAYERS` | `40` | Player limit | `ServerSettings.ini` / `ServerSettings.MaxPlayers`; `Game.ini` / `/Script/Engine.GameSession.MaxPlayers` |
| `GAME_PORT` | `7777` | Game UDP port | `ServerSettings.ini` / `ServerSettings.Port`; `Engine.ini` / `URL.Port` |
| `PINGER_PORT` | `7778` | Pinger UDP port | `ServerSettings.ini` / `ServerSettings.PingerPort` |
| `QUERY_PORT` | `27015` | Steam query UDP port | `ServerSettings.ini` / `ServerSettings.QueryPort`; `Engine.ini` / `OnlineSubsystemSteam.GameServerQueryPort` |
| `RCON_ENABLED` | `true` | RCON toggle | `ServerSettings.ini` / `ServerSettings.RconEnabled` |
| `RCON_PORT` | `25575` | RCON TCP port | `ServerSettings.ini` / `ServerSettings.RconPort` |
| `RCON_PASSWORD` | empty | RCON password | `ServerSettings.ini` / `ServerSettings.RconPassword` |
| `FORCE_QUERY_PORT_ARG` | `true` | Add explicit `-QueryPort=<QUERY_PORT>` launch arg | Launch command |
| `MULTIHOME_IP` | empty | Optional `-MULTIHOME=<value>` launch arg for binding diagnostics | Launch command |
| `MULTIHOME_HTTP_IP` | empty | Optional `-MULTIHOMEHTTP=<value>` launch arg for HTTP binding diagnostics | Launch command |
| `UPDATE_SERVER_ON_START` | `true` | Run selected download backend update on startup | Startup behavior |
| `VALIDATE_SERVER_FILES` | `false` | Add backend validation when supported | SteamCMD/DepotDownloader update behavior |
| `DOWNLOAD_BACKEND` | `depotdownloader` | Server download backend: `steamcmd`, `depotdownloader`, or `auto` | Startup update behavior |
| `AUTO_GAME_UPDATE` | `false` | Planned background update loop | Not active in MVP |
| `AUTO_GAME_UPDATE_INTERVAL_MINUTES` | `360` | Planned loop interval | Not active in MVP |
| `UPDATE_MODS_ON_START` | `true` | Download/update mods on startup | Startup behavior |
| `MOD_DOWNLOAD_BACKEND` | `depotdownloader` | Workshop mod backend: `steamcmd`, `depotdownloader`, or `auto` | Startup mod update behavior |
| `AUTO_MOD_UPDATE` | `false` | Planned background mod update loop | Not active in MVP |
| `WORKSHOP_MOD_IDS` | empty | Comma-separated ordered Workshop IDs | `ConanSandbox/Mods/modlist.txt` |
| `PRUNE_REMOVED_MODS` | `true` | Remove no-longer-listed downloaded mods | Steam Workshop content directory |
| `BACKUP_LOCATION` | `/serverdata/backups` | Backup archive directory | Backup script |
| `BACKUP_ON_START` | `true` | Backup before startup update/mod operations | Backup script |
| `BACKUP_ON_STOP` | `false` | Backup during graceful shutdown | Entrypoint shutdown |
| `BACKUP_RETENTION_DAYS` | `14` | Delete older backup archives when positive | Backup script |
| `EXTRA_ARGS` | empty | Extra server launch args, split on spaces | Launch command |

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

`WORKSHOP_MOD_IDS` is parsed as a comma-separated ordered list. Each ID is downloaded with `MOD_DOWNLOAD_BACKEND` using Workshop app ID `440900`. The generated mod list is written to `ConanSandbox/Mods/modlist.txt` in the same order. Removed downloads are pruned only when `PRUNE_REMOVED_MODS=true`.

Verified public test item: `3720546346` (`[Enhanced] Unlimited Weight`).

- DepotDownloader default backend produced `HEUnlimitedWeight.pak` under Docker default security.
- SteamCMD produced the same `.pak` when run with diagnostic `seccomp=unconfined`.
- Clean e2e compose run started to `StartPlay` with the generated modlist in place.

## Testing Requirements

- Build the image locally.
- Run clean first boot with empty/disposable data folders.
- Confirm server files download with the selected backend.
- Confirm native Linux launcher/executable exists.
- Confirm config files are created and env values apply.
- Confirm server process starts to `StartPlay` or an equivalent known-good marker.
- Confirm graceful shutdown.
- Confirm restart does not wipe saves/config/modlist.
- Confirm Workshop mod download and ordered modlist generation.
- Confirm backup creation.
- Confirm logs do not expose passwords.
- Confirm project-control docs are current.
- For live client testing, follow `docs/LOCAL_LIVE_TEST.md` and leave the server running for the user when it reaches readiness.
- Run `tests/steamcmd-connectivity.ps1` or `tests/steamcmd-connectivity.sh` when SteamCMD anonymous login or AppID download fails.

## Phase 2 WebGUI Notes

The WebGUI is planned only. See `docs/WEBGUI_PHASE_2.md`.
