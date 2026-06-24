# Project Map

Future sessions should read this file first, then `PROJECT.md`, `AGENTS.md`, and `SESSION_HANDOFF.md`.

## Repository Layout

- `AGENTS.md`: project-specific working rules for Codex/agents, including GitHub automation rules.
- `PROJECT.md`: project goal, scope, MVP definition, repository identity, visibility, environment variables, ports, volumes, and decisions.
- `PROJECT_MAP.md`: routing/index document for the repository.
- `SESSION_HANDOFF.md`: continuity notes, latest status, latest push/remote status, tests, blockers, and next steps.
- `.env`: committed safe defaults for normal compose use. Do not put real passwords, local live names, or machine-specific values here.
- `Dockerfile`: Ubuntu-based image with SteamCMD, runtime dependencies, scripts, exposed ports, and healthcheck.
- `docker-compose.yml`: local Docker Desktop compose service with required volume and port mappings.
- `docker-compose.steamcmd-unconfined.diagnostic.yml`: diagnostic/emergency-only compose override that sets `security_opt: seccomp=unconfined` for SteamCMD troubleshooting. It is less secure than default Docker isolation and is not enabled by default.
- `.env.example`: complete environment variable template.
- `.dockerignore`: excludes git metadata, local runtime data, and local environment files from Docker build context.
- `.gitignore`: excludes local runtime data and host/editor noise.
- `README.md`: practical user guide.
- `scripts/`: container lifecycle scripts.
- `docs/`: focused operational docs.
- `data/`: ignored local runtime data for Docker Desktop volume mounts.
- `tests/`: local validation and diagnostic scripts.
- `test-results/`: ignored local diagnostic output.

## Script Responsibilities

- `scripts/common.sh`: shared logging, boolean parsing, path defaults, validation, and server executable discovery.
- `scripts/entrypoint.sh`: runtime user setup, directory prep, SteamCMD home seeding, safe logging, backup/update/config/mod orchestration, signal handling.
- `scripts/install-depotdownloader.sh`: build-time installer for pinned DepotDownloader release `DepotDownloader_3.4.0`.
- `scripts/update-server.sh`: selected backend install/update for AppID `443030`, Linux platform request, timestamped backend logs, DepotDownloader-first `DOWNLOAD_BACKEND=auto` fallback, and native executable verification.
- `scripts/configure-server.sh`: persistent config/log directory linking and managed-key environment-driven config writes. Server name/password are written to active `Engine.ini` `[OnlineSubsystem]` and mirrored to `ServerSettings.ini`; `SERVER_REGION` accepts readable aliases such as `America` and writes numeric `ServerSettings.serverRegion`.
- `scripts/update-mods.sh`: selected Workshop backend download/update, ordered modlist generation, removed-mod pruning, and DepotDownloader-first `MOD_DOWNLOAD_BACKEND=auto` fallback.
- `scripts/backup.sh`: timestamped archive creation and retention cleanup.
- `scripts/start-server.sh`: native launcher/executable discovery, redacted launch-argument logging, explicit query-port argument support, optional multihome launch arguments, and foreground server launch. The verified downloaded launcher is `ConanSandboxServer.sh`; fallback direct executable is `ConanSandbox/Binaries/Linux/ConanSandboxServer-Linux-Shipping`.
- `scripts/healthcheck.sh`: server process healthcheck.
- `tests/steamcmd-connectivity.ps1`: Windows/PowerShell SteamCMD connectivity diagnostics for host public internet, container networking/DNS, project image SteamCMD, upstream SteamCMD, DNS overrides, and optional host networking.
- `tests/steamcmd-connectivity.sh`: Bash SteamCMD connectivity diagnostics for compatible Linux/macOS/Git Bash shells.
- `tests/depotdownloader-connectivity.ps1`: Windows/PowerShell DepotDownloader diagnostics for pinned release reachability, image-installed binary version, AppID `443030` manifest-only access, and bounded explicit DepotDownloader app update.
- `tests/depotdownloader-connectivity.sh`: Bash DepotDownloader diagnostics for compatible Linux/macOS/Git Bash shells.
- `tests/windows-steamcmd-comparison.ps1`: Windows host SteamCMD comparison diagnostic. Detects `WINDOWS_STEAMCMD_EXE` or common launcher locations and runs anonymous login/app-info without secrets.
- `tests/steamcmd-security-diagnostics.ps1`: Windows/PowerShell Docker security diagnostics for Docker version/info/context, default seccomp, diagnostic `seccomp=unconfined`, optional custom seccomp profile, project image, upstream image, and optional host networking.
- `tests/steamcmd-security-diagnostics.sh`: Bash Docker security diagnostics for compatible Linux/macOS/Git Bash shells.
- `tests/local-live-status.ps1`: Windows/PowerShell local live-server status helper for compose service state, published ports, recent `StartPlay`, password leak scan, and local data disk usage.
- `tests/local-lan-server-diagnostics.ps1`: Windows/PowerShell LAN-client listing/connectivity diagnostic for host LAN IPv4 addresses, Docker published ports, in-container sockets, host port owners, Windows Firewall rule status, listing/query log clues, password leak scan, disk usage, and exact other-LAN-client test steps.
- `tests/local-env-effective-diagnostics.ps1`: Windows/PowerShell masked local env diagnostic for env-file values, compose effective environment, container environment, and local live name/password presence.
- `tests/conan-config-effective-diagnostics.ps1`: Windows/PowerShell masked active Conan config diagnostic for active config path, `Engine.ini` `[OnlineSubsystem]` name/password, ports, `ServerSettings.ini` admin/password values, and key inventory.
- `tests/windows-firewall-conan-rules.ps1`: Windows/PowerShell check/apply/remove helper for narrow inbound Conan rules. Check-only by default; `-Apply` and `-Remove` require Administrator PowerShell.

## Data And Volume Layout

Container paths:

- `/serverdata/serverfiles`: installed dedicated server files and server state.
- `/serverdata/steam`: SteamCMD home/cache and Workshop content.
- `/serverdata/config`: persistent config files linked into the server tree.
- `/serverdata/logs`: persistent logs linked into the server tree.
- `/serverdata/backups`: backup archives.

Local Docker Desktop paths:

- `./data/serverfiles`
- `./data/steam`
- `./data/config`
- `./data/logs`
- `./data/backups`

## Current Runtime Assumptions

- The local Codex host has public internet access but no LAN access; Rocky Linux and Unraid connectivity tests must not be attempted from this host.
- DepotDownloader is the default server and Workshop mod download backend.
- Docker Engine `29.4.2` with builtin seccomp blocks Linux SteamCMD in this Docker Desktop environment.
- Windows host SteamCMD succeeds from `C:\Conan Exiles Server\DedicatedServerLauncher\steamcmd.exe`.
- Docker `seccomp=unconfined` makes Linux SteamCMD login/app-info pass, proving the failure is Docker security-profile specific.
- `docker-compose.steamcmd-unconfined.diagnostic.yml` exists only for diagnostic/emergency use. Prefer the default DepotDownloader backend or a Docker Engine/Desktop upgrade for normal local work.
- DepotDownloader is pinned to `DepotDownloader_3.4.0` and installed into the image at build time.
- `DOWNLOAD_BACKEND=steamcmd` uses only SteamCMD.
- `DOWNLOAD_BACKEND=depotdownloader` uses only DepotDownloader.
- `DOWNLOAD_BACKEND=auto` tries DepotDownloader first and logs the failure path before trying SteamCMD.
- `MOD_DOWNLOAD_BACKEND=steamcmd` uses only SteamCMD for Workshop mods.
- `MOD_DOWNLOAD_BACKEND=depotdownloader` uses only DepotDownloader for Workshop mods.
- `MOD_DOWNLOAD_BACKEND=auto` tries DepotDownloader first and logs the failure path before trying SteamCMD.
- Native Linux server files are verified from a DepotDownloader AppID `443030` download on June 23, 2026.
- Verified native launcher: `ConanSandboxServer.sh`.
- Verified native executable: `ConanSandbox/Binaries/Linux/ConanSandboxServer-Linux-Shipping`.
- Conan config profile is `LinuxServer` after `configure-server.sh`; the bounded launch probe loaded `ConanSandbox/Saved/Config/LinuxServer/ServerSettings.ini`.
- Workshop downloads use Steam Workshop app ID `440900`.
- Active mod list is `ConanSandbox/Mods/modlist.txt`.
- Single-mod Workshop download was verified under diagnostic `seccomp=unconfined` using public item `3720546346`; verified `.pak` file was `HEUnlimitedWeight.pak`.
- DepotDownloader Workshop download was verified under Docker default security using public item `3720546346`; verified `.pak` file was `HEUnlimitedWeight.pak`.
- Clean disposable compose e2e using the DepotDownloader defaults downloaded AppID `443030`, generated config, downloaded Workshop item `3720546346`, generated `ConanSandbox/Mods/modlist.txt`, reached `StartPlay`, stopped gracefully, restarted, preserved config/modlist, created backups, and removed large disposable server/cache folders after preserving proof logs.
- Local live-client testing uses ignored `.env.local-live` or `.env.test-live` files. Do not commit local live passwords or generated `data/`.
- Future live client, listing, password, and public registration claims must be confirmed by the user from an actual Conan Exiles client before they are recorded as verified.
- Local Docker Desktop LAN diagnostics on June 24, 2026 verified Docker publishing and in-container listeners for `7777/udp`, `7778/udp`, and `27015/udp`; Windows Firewall had no specific inbound allow rules for those Docker-published ports.
- The local live launch command includes `-QueryPort=27015` when `FORCE_QUERY_PORT_ARG=true`.
- `MULTIHOME_IP` and `MULTIHOME_HTTP_IP` exist for diagnostics but should remain empty unless host/IP binding is being explicitly tested.
- User confirmed direct LAN connect, correct server name, password behavior, admin password behavior, and America/North America region display from another Conan Exiles client. The env reached the container; `SERVER_NAME` and `SERVER_PASSWORD` are written to active `Engine.ini` `[OnlineSubsystem]`, and `SERVER_REGION=America` resolves to `serverRegion=1`.
- Auto update loops are not active in MVP.

Multi-mod ordering, mod removal/pruning, long-running server behavior, Rocky Linux, and Unraid still need later verification.

## Documentation

- `docs/CONFIG.md`: config and environment variable mapping.
- `docs/MODS.md`: Workshop mod behavior.
- `docs/BACKUPS.md`: backup and restore basics.
- `docs/LOCAL_DOCKER_DESKTOP.md`: local test procedure and current status.
- `docs/LOCAL_LIVE_TEST.md`: local Docker Desktop live-client test workflow, LAN-client connection checklist, diagnostics, and firewall helper commands.
- `docs/ROCKY_LINUX.md`: Rocky Linux deployment/test notes.
- `docs/WEBGUI_PHASE_2.md`: future WebGUI design.
- `docs/TROUBLESHOOTING_STEAMCMD.md`: SteamCMD/Docker Desktop connectivity blocker explanation and diagnostic workflow.
- `docs/TROUBLESHOOTING_SERVER_LISTING.md`: LAN server-browser listing and direct-connect troubleshooting for Docker Desktop, Conan query/pinger ports, Windows Firewall, startup report clues, and user report-back checklist.
- `test-results/`: ignored diagnostic output created on demand by troubleshooting scripts. Disposable local contents can be removed after important proof/status is summarized in `PROJECT.md` and `SESSION_HANDOFF.md`.

## Git And GitHub Workflow

- `AGENTS.md`: permanent automation-first GitHub rules for agents.
- `PROJECT.md`: repository name, expected owner/remote, and private visibility expectation.
- `SESSION_HANDOFF.md`: latest branch, commit, remote URL, repo creation status, push status, and any GitHub automation blockers.
