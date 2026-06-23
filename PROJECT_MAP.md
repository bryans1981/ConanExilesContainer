# Project Map

Future sessions should read this file first, then `PROJECT.md`, `AGENTS.md`, and `SESSION_HANDOFF.md`.

## Repository Layout

- `AGENTS.md`: project-specific working rules for Codex/agents, including GitHub automation rules.
- `PROJECT.md`: project goal, scope, MVP definition, repository identity, visibility, environment variables, ports, volumes, and decisions.
- `PROJECT_MAP.md`: routing/index document for the repository.
- `SESSION_HANDOFF.md`: continuity notes, latest status, latest push/remote status, tests, blockers, and next steps.
- `Dockerfile`: Ubuntu-based image with SteamCMD, runtime dependencies, scripts, exposed ports, and healthcheck.
- `docker-compose.yml`: local Docker Desktop compose service with required volume and port mappings.
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
- `scripts/update-server.sh`: selected backend install/update for AppID `443030`, Linux platform request, timestamped backend logs, explicit `DOWNLOAD_BACKEND=auto` fallback, and native executable verification.
- `scripts/configure-server.sh`: persistent config/log directory linking and environment-driven config writes.
- `scripts/update-mods.sh`: Workshop mod download/update, ordered modlist generation, removed-mod pruning.
- `scripts/backup.sh`: timestamped archive creation and retention cleanup.
- `scripts/start-server.sh`: native launcher/executable discovery and foreground server launch. The verified downloaded launcher is `ConanSandboxServer.sh`; fallback direct executable is `ConanSandbox/Binaries/Linux/ConanSandboxServer-Linux-Shipping`.
- `scripts/healthcheck.sh`: server process healthcheck.
- `tests/steamcmd-connectivity.ps1`: Windows/PowerShell SteamCMD connectivity diagnostics for host public internet, container networking/DNS, project image SteamCMD, upstream SteamCMD, DNS overrides, and optional host networking.
- `tests/steamcmd-connectivity.sh`: Bash SteamCMD connectivity diagnostics for compatible Linux/macOS/Git Bash shells.
- `tests/depotdownloader-connectivity.ps1`: Windows/PowerShell DepotDownloader diagnostics for pinned release reachability, image-installed binary version, AppID `443030` manifest-only access, and bounded explicit DepotDownloader app update.
- `tests/depotdownloader-connectivity.sh`: Bash DepotDownloader diagnostics for compatible Linux/macOS/Git Bash shells.

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
- SteamCMD remains the default backend and currently fails anonymous login from Docker Desktop with `FAILED (No Connection)`.
- DepotDownloader is an explicit diagnostic/fallback backend. It is pinned to `DepotDownloader_3.4.0` and installed into the image at build time.
- `DOWNLOAD_BACKEND=steamcmd` uses only SteamCMD.
- `DOWNLOAD_BACKEND=depotdownloader` uses only DepotDownloader.
- `DOWNLOAD_BACKEND=auto` tries SteamCMD first and logs the SteamCMD failure path before trying DepotDownloader.
- Native Linux server files are verified from a DepotDownloader AppID `443030` download on June 23, 2026.
- Verified native launcher: `ConanSandboxServer.sh`.
- Verified native executable: `ConanSandbox/Binaries/Linux/ConanSandboxServer-Linux-Shipping`.
- Conan config profile is `LinuxServer` after `configure-server.sh`; the bounded launch probe loaded `ConanSandbox/Saved/Config/LinuxServer/ServerSettings.ini`.
- Workshop downloads use Steam Workshop app ID `440900`.
- Active mod list is `ConanSandbox/Mods/modlist.txt`.
- Auto update loops are not active in MVP.

Workshop download/modlist behavior and full compose first boot must still be verified before MVP success is claimed.

## Documentation

- `docs/CONFIG.md`: config and environment variable mapping.
- `docs/MODS.md`: Workshop mod behavior.
- `docs/BACKUPS.md`: backup and restore basics.
- `docs/LOCAL_DOCKER_DESKTOP.md`: local test procedure and current status.
- `docs/ROCKY_LINUX.md`: Rocky Linux deployment/test notes.
- `docs/WEBGUI_PHASE_2.md`: future WebGUI design.
- `docs/TROUBLESHOOTING_STEAMCMD.md`: SteamCMD/Docker Desktop connectivity blocker explanation and diagnostic workflow.
- `test-results/depotdownloader-connectivity/`: ignored proof logs from DepotDownloader diagnostics, including the successful AppID `443030` download and bounded launch probe from June 23, 2026.

## Git And GitHub Workflow

- `AGENTS.md`: permanent automation-first GitHub rules for agents.
- `PROJECT.md`: repository name, expected owner/remote, and private visibility expectation.
- `SESSION_HANDOFF.md`: latest branch, commit, remote URL, repo creation status, push status, and any GitHub automation blockers.
