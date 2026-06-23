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

Current MVP status: scaffold and local image validation are complete, and DepotDownloader can download AppID `443030` from this Docker Desktop host. MVP success is still not claimed because Docker Engine `29.4.2` blocks Linux SteamCMD under the default builtin seccomp profile, Workshop mod loading has not been verified in a live server launch, and the full compose first-boot path still needs end-to-end validation.

## Required Features

- SteamCMD install/update for AppID `443030`.
- Controlled `DOWNLOAD_BACKEND` support for `steamcmd`, `depotdownloader`, and explicit `auto` fallback.
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
- DepotDownloader `DepotDownloader_3.4.0` installs into the image at build time from the official SteamRE GitHub release.
- `DOWNLOAD_BACKEND=depotdownloader` successfully downloaded AppID `443030` on June 23, 2026.
- The downloaded server tree contains the verified native launcher `ConanSandboxServer.sh`.
- The downloaded server tree contains the verified native executable `ConanSandbox/Binaries/Linux/ConanSandboxServer-Linux-Shipping`.
- A bounded launch probe using the verified launcher loaded `ConanSandbox/Saved/Config/LinuxServer/ServerSettings.ini`, opened the game port, and reached `StartPlay`.
- Windows host SteamCMD at `C:\Conan Exiles Server\DedicatedServerLauncher\steamcmd.exe` can start, anonymously log in, and print AppID `443030` app info.
- Docker Engine `29.4.2` with builtin seccomp fails Linux SteamCMD login/app-info in both the project image and upstream `steamcmd/steamcmd:ubuntu-24`.
- Diagnostic `seccomp=unconfined` makes Linux SteamCMD login/app-info pass in both the project image and upstream image. This proves the local SteamCMD failure is Docker security-profile specific, not a general Steam or host internet failure.
- The diagnostic compose override `docker-compose.steamcmd-unconfined.diagnostic.yml` renders successfully and is available only as a diagnostic/emergency workaround.
- Workshop mod download with SteamCMD works under diagnostic `seccomp=unconfined` for public Conan Workshop item `3720546346` (`[Enhanced] Unlimited Weight`).
- Verified Workshop `.pak` path from that test: `steamapps/workshop/content/440900/3720546346/HEUnlimitedWeight.pak`.
- The project wrote the active mod list at `ConanSandbox/Mods/modlist.txt` with the downloaded `.pak` path in `WORKSHOP_MOD_IDS` order.
- SteamCMD starts successfully when using the seeded non-root Steam home under `/serverdata/steam`.
- Config generation creates persistent `LinuxServer` config files and applies environment values without logging passwords.
- Empty `WORKSHOP_MOD_IDS` creates an empty active mod list.
- Backup creation works.
- Server start fails loudly when no native Linux executable exists.

## Current Blocker

SteamCMD anonymous login fails from Docker Desktop on this host before AppID `443030` can be downloaded through the default backend and default Docker security profile:

```text
CreateBoundSocket: failed to create socket, error [no name available] (38)
Connecting anonymously to Steam Public...
FAILED (No Connection)
```

The same failure happens with the upstream `steamcmd/steamcmd:ubuntu-24` image under the default builtin seccomp profile. The same upstream image succeeds when run with `--security-opt seccomp=unconfined`, and Windows host SteamCMD succeeds directly. This is treated as a Docker Engine/Desktop `29.4.2` seccomp compatibility issue.

Diagnostics run on June 23, 2026 show:

- Host public DNS: pass.
- Host public HTTPS: pass.
- Docker Desktop engine: pass.
- Generic container DNS: pass.
- Generic container HTTPS: pass.
- Generic container Ubuntu package repository reachability: pass.
- Docker DNS overrides with `1.1.1.1` and `8.8.8.8`: pass.
- Project image SteamCMD anonymous login/app-info/update checks: inconclusive/failing at SteamCMD connection.
- Upstream `steamcmd/steamcmd:ubuntu-24` anonymous login/app-info checks: inconclusive/failing at SteamCMD connection.
- Upstream SteamCMD with public DNS override and host networking: inconclusive/failing at SteamCMD connection.
- Windows host SteamCMD comparison: pass.
- Docker security diagnostics: default builtin seccomp fails; diagnostic `seccomp=unconfined` passes.

Current evidence isolates the problem to Docker `29.4.2` builtin seccomp behavior for Linux SteamCMD in containers. It does not indicate a general host internet, generic container internet, Docker DNS, AppID availability, or native Linux file-layout failure.

Docker details captured locally:

- Docker Desktop: `4.72.0 (225998)`
- Docker Engine: `29.4.2`
- containerd: `v2.2.3`
- runc: `1.3.5`
- Docker context: `desktop-linux`
- Security options: `seccomp`, profile `builtin`

Docker's Engine 29 release notes document that `29.4.2` blocks `AF_ALG` sockets and `socketcall(2)` in the default seccomp profile and lists SteamCMD as an affected workload. Docker's `29.4.3` notes document replacing that broad `socketcall` deny with targeted LSM controls. Preferred remediation is to upgrade Docker Engine/Desktop to a version containing that fix. The local project does not change the user's Docker installation automatically.

DepotDownloader comparison on June 23, 2026:

- Official release checked: `DepotDownloader_3.4.0`.
- Image binary reported `DepotDownloader v3.4.0+c553ef4d60c00a4f5fd16c9fe017f569001589ff`.
- Anonymous AppID `443030` manifest-only access passed.
- Anonymous AppID `443030` Linux download passed with `DOWNLOAD_BACKEND=depotdownloader`.
- Downloaded depots included Linux depot `443032`.
- Download summary reported `3997931312` bytes downloaded and `4727137130` bytes uncompressed.
- Verified launcher: `ConanSandboxServer.sh`.
- Verified executable: `ConanSandbox/Binaries/Linux/ConanSandboxServer-Linux-Shipping`.
- Initial downloaded config file found before first launch: `Engine/Config/StagedBuild_ConanSandbox.ini`.
- Generated persistent config path after `configure-server.sh`: `ConanSandbox/Saved/Config/LinuxServer/`.
- Generated config files after the launch probe: `ServerSettings.ini`, `Engine.ini`, and `Game.ini`.
- Server log path after the launch probe: `ConanSandbox/Saved/Logs/ConanSandbox.log`.

This comparison proves that the native Linux server files are available through DepotDownloader from this environment. SteamCMD remains the default variable value, but `DOWNLOAD_BACKEND=depotdownloader` is the recommended normal backend on this Docker Desktop `29.4.2` host until Docker is upgraded or a safe seccomp profile is verified.

External SteamDB metadata, last checked June 23, 2026, lists AppID `443030` as supporting Windows and Linux, with Linux depot `443032` and Linux launch executable `ConanSandbox\Binaries\Linux\ConanSandboxServer`. This is useful orientation only; it does not replace local verification from downloaded files.

References:

- https://steamdb.info/app/443030/depots/
- https://steamdb.info/app/443030/config/

## Local Environment Clarification

- The local Codex host has public internet access.
- The local Codex host does not have LAN access by design.
- LAN, Rocky Linux, and Unraid connectivity tests are not valid from this environment.
- Docker Desktop diagnostics from this host should focus on public internet access, container networking, Docker DNS, firewall/security filtering, proxy/VPN behavior, and SteamCMD/Steam protocol access from inside containers.
- Rocky Linux comparison testing must be run later from the Rocky Linux Docker host itself.

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
| `UPDATE_SERVER_ON_START` | `true` | Run selected download backend update on startup | Startup behavior |
| `VALIDATE_SERVER_FILES` | `false` | Add backend validation when supported | SteamCMD/DepotDownloader update behavior |
| `DOWNLOAD_BACKEND` | `steamcmd` | Server download backend: `steamcmd`, `depotdownloader`, or `auto` | Startup update behavior |
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

Config key paths above were generated and loaded during the bounded DepotDownloader launch probe. Workshop/modlist behavior and full first boot still must be verified before claiming MVP success.

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

Workshop app ID `440900`, `.pak` discovery, and project modlist writing were verified with real downloaded mod files from public Conan Workshop item `3720546346`. The generated mod list path is `ConanSandbox/Mods/modlist.txt`, and the test line was the absolute `.pak` path under the Steam Workshop content directory. Server-side mod loading from that modlist still requires a live modded server launch before MVP success is claimed.

A DepotDownloader full pubfile download for the same item succeeded once and produced `HEUnlimitedWeight.pak`, but later immediate retries failed to connect to Steam. `MOD_DOWNLOAD_BACKEND` is therefore not implemented.

## Testing Requirements

- Build the image locally.
- Run clean first boot with empty `./data` folders.
- Confirm server files download with SteamCMD default path or an explicitly selected alternate backend.
- Confirm native Linux executable exists. Verified through DepotDownloader on June 23, 2026.
- Confirm config files are created and env values apply.
- Confirm server process starts and stops gracefully.
- Confirm restart does not wipe saves/config.
- Confirm update toggle behavior.
- Confirm Workshop mod download, ordering, removal, pruning, and backup behavior. Single-mod download/order is verified under diagnostic `seccomp=unconfined`; multi-mod ordering, pruning, backup interaction, and live server loading remain unverified.
- Confirm logs do not expose passwords.
- Confirm project-control docs are current.
- Run `tests/steamcmd-connectivity.ps1` or `tests/steamcmd-connectivity.sh` when SteamCMD anonymous login or AppID download fails.

## Phase 2 WebGUI Notes

The WebGUI is planned only. See `docs/WEBGUI_PHASE_2.md`.
