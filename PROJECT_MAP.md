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
- `scripts/update-server.sh`: SteamCMD install/update for AppID `443030`, Linux platform request, native executable verification.
- `scripts/configure-server.sh`: persistent config/log directory linking and environment-driven config writes.
- `scripts/update-mods.sh`: Workshop mod download/update, ordered modlist generation, removed-mod pruning.
- `scripts/backup.sh`: timestamped archive creation and retention cleanup.
- `scripts/start-server.sh`: native executable discovery and foreground server launch.
- `scripts/healthcheck.sh`: server process healthcheck.
- `tests/steamcmd-connectivity.ps1`: Windows/PowerShell SteamCMD connectivity diagnostics for host public internet, container networking/DNS, project image SteamCMD, upstream SteamCMD, DNS overrides, and optional host networking.
- `tests/steamcmd-connectivity.sh`: Bash SteamCMD connectivity diagnostics for compatible Linux/macOS/Git Bash shells.

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
- SteamCMD can access AppID `443030` anonymously.
- Native Linux server files exist or the container will fail loudly.
- External SteamDB metadata currently lists Linux depot `443032` and Linux executable `ConanSandbox\Binaries\Linux\ConanSandboxServer`, but local download verification is blocked.
- Conan config profile is `LinuxServer` when present, otherwise `WindowsServer` if the downloaded files only provide that folder, otherwise a new `LinuxServer` config folder is created.
- Workshop downloads use Steam Workshop app ID `440900`.
- Active mod list is `ConanSandbox/Mods/modlist.txt`.
- Auto update loops are not active in MVP.

All assumptions above must be verified by local Docker Desktop testing before MVP success is claimed.

## Documentation

- `docs/CONFIG.md`: config and environment variable mapping.
- `docs/MODS.md`: Workshop mod behavior.
- `docs/BACKUPS.md`: backup and restore basics.
- `docs/LOCAL_DOCKER_DESKTOP.md`: local test procedure and current status.
- `docs/ROCKY_LINUX.md`: Rocky Linux deployment/test notes.
- `docs/WEBGUI_PHASE_2.md`: future WebGUI design.
- `docs/TROUBLESHOOTING_STEAMCMD.md`: SteamCMD/Docker Desktop connectivity blocker explanation and diagnostic workflow.

## Git And GitHub Workflow

- `AGENTS.md`: permanent automation-first GitHub rules for agents.
- `PROJECT.md`: repository name, expected owner/remote, and private visibility expectation.
- `SESSION_HANDOFF.md`: latest branch, commit, remote URL, repo creation status, push status, and any GitHub automation blockers.
