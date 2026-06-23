# Session Handoff

## Current Status

Initial MVP scaffold is complete and locally validated as far as possible without Steam anonymous login. Docker Desktop is available on the local host. The private GitHub repository exists and `main` is pushed to `origin`.

Current Git/GitHub state:

- Current branch: `main`
- Current baseline commit before SteamCMD diagnostics work: `7d8abfa Add GitHub automation rules`
- Initial scaffold commit: `9ae5a6f Initial Conan Exiles container scaffold`
- Remote URL: `https://github.com/bryans1981/ConanExilesContainer.git`
- Remote name: `origin`
- Repo creation: succeeded through GitHub REST API using Git Credential Manager credentials after `gh` was confirmed unavailable.
- Push status before this work: clean against `origin/main`.
- GitHub visibility: private.
- Local git author config: `bryans1981 <bryans1981@users.noreply.github.com>`.

Local environment clarification:

- The Codex host has public internet access.
- The Codex host has no LAN access by design.
- LAN, Rocky Linux, and Unraid connectivity tests are not valid from this environment.
- Docker Desktop diagnostics from this host should focus on public internet, container networking/DNS, firewall/security filtering, proxy/VPN behavior, and SteamCMD/Steam protocol behavior inside containers.

## Completed

- Created required project-control documents.
- Added Dockerfile, compose file, `.env.example`, `.gitignore`, `.dockerignore`, README, docs, and lifecycle scripts.
- Implemented SteamCMD install/update targeting AppID `443030`.
- Switched to the `steamcmd/steamcmd:ubuntu-24` base image and seeded `/serverdata/steam` with a bootstrapped SteamCMD home so SteamCMD can run as the configured non-root user.
- Implemented native Linux executable verification and clear failure if only Windows executables are found.
- Implemented runtime `PUID`/`PGID`, persistent directories, config/log linking, backups, mod downloads, modlist generation, and healthcheck.
- Marked `AUTO_GAME_UPDATE` and `AUTO_MOD_UPDATE` as planned/not active instead of pretending they work.
- Verified compose config, Bash syntax, Docker build, SteamCMD startup, config generation, empty modlist handling, backup creation, and no-executable failure behavior.
- Created private GitHub repository `bryans1981/ConanExilesContainer`.
- Added `origin` remote and pushed `main`.
- Added permanent GitHub automation-first rules to the project-control docs.
- Added repeatable SteamCMD diagnostics:
  - `tests/steamcmd-connectivity.ps1`
  - `tests/steamcmd-connectivity.sh`
- Added `docs/TROUBLESHOOTING_STEAMCMD.md`.
- Updated `scripts/update-server.sh` to tee SteamCMD output to timestamped logs under `/serverdata/logs/steamcmd`.
- Updated project docs with the local public-internet-only/no-LAN environment model.

## In Progress

- SteamCMD verification of actual AppID `443030` server file layout.
- Full first boot after Steam anonymous login works.

## Next Recommended Steps

1. Retest SteamCMD later using `tests/steamcmd-connectivity.ps1` or `tests/steamcmd-connectivity.sh` to see whether SteamCMD anonymous login recovers.
2. If Docker Desktop SteamCMD remains blocked, run the same diagnostics from a different Docker host that has public internet access, such as the Rocky Linux Docker host itself. Do not test Rocky/Unraid/LAN access from this Codex host.
3. Run `docker compose up` with empty `./data` folders once Steam login works.
4. Confirm whether AppID `443030` provides the expected native Linux executable.
5. If native files exist, verify executable name, config paths, launch syntax, and modlist behavior from downloaded files.
6. If only Windows files exist, decide whether to add a documented optional Wine fallback in a later phase.
7. Test Workshop mod download with known mod IDs.

## Known Blockers

- SteamCMD anonymous login fails from Docker Desktop with `FAILED (No Connection)`. The same failure occurs in the upstream `steamcmd/steamcmd:ubuntu-24` image and with Docker host networking.
- Native Linux server availability for AppID `443030` has not yet been proven by a completed SteamCMD install in this environment.
- Host public internet, generic container internet, and Docker DNS passed diagnostics on June 23, 2026. The blocker is isolated to SteamCMD/Steam protocol behavior from containers or a temporary Steam-side issue.

GitHub automation blockers: none currently. `gh` is unavailable, but Git Credential Manager provided authenticated credentials and the GitHub REST API repo creation path succeeded without printing secrets.

## Known Risks

- Config key paths and modlist behavior are implemented as expected Conan/Unreal dedicated server paths but still require verification against real downloaded server files.
- External SteamDB metadata indicates Linux support, but this is not a substitute for local downloaded-file verification.
- `EXTRA_ARGS` is split on spaces and does not support shell-style quoting.
- Background auto update loops are not active in MVP.
- Diagnostic output under `test-results/` and runtime data under `data/` are intentionally ignored by git.

## Latest Test Results

- `docker version`: passed; Docker Desktop engine is available.
- `gh auth status`: failed; `gh` command is not installed.
- `git config --get credential.helper`: Git Credential Manager is configured.
- Git Credential Manager non-interactive credential probe: GitHub username/password fields were present; secret values were not printed.
- GitHub connector `_get_repo` for `bryans1981/ConanExilesContainer`: initially returned 404 before creation.
- `git ls-remote https://github.com/bryans1981/ConanExilesContainer.git HEAD`: initially returned repository not found before creation.
- GitHub REST `POST /user/repos`: created private repo `https://github.com/bryans1981/ConanExilesContainer`.
- `git push -u origin main`: passed for initial scaffold commit.
- `docker compose config`: passed.
- Bash syntax check for all scripts using Ubuntu container: passed.
- `docker compose build`: passed.
- Project image SteamCMD smoke test with seeded `/serverdata/steam`: passed.
- AppID `443030` SteamCMD update: blocked by Steam anonymous login failure.
- Upstream `steamcmd/steamcmd:ubuntu-24` anonymous login: failed the same way.
- Config generation/linking: passed.
- Empty modlist handling: passed.
- Backup creation: passed.
- Start without downloaded executable: failed loudly as expected.
- Full Docker first boot: blocked by Steam anonymous login failure.
- `docker compose config`: passed again after diagnostics changes.
- Bash syntax check for all scripts and `tests/steamcmd-connectivity.sh`: passed.
- PowerShell parser check for `tests/steamcmd-connectivity.ps1`: passed.
- `docker compose build`: passed after `update-server.sh` logging change.
- PowerShell SteamCMD diagnostics `tests/steamcmd-connectivity.ps1`: passed as a diagnostic run with `FailureCount=0`, `InconclusiveCount=7`, `SteamFailureCount=7`.
- Bash SteamCMD diagnostics `bash tests/steamcmd-connectivity.sh --skip-app-update-attempt --skip-host-network`: passed as a diagnostic run with `FailureCount=0`, `InconclusiveCount=6`, `SteamFailureCount=5`.
- Diagnostic evidence:
  - Host DNS/HTTPS: pass.
  - Generic container DNS/HTTPS/package repositories: pass.
  - Docker public DNS overrides `1.1.1.1` and `8.8.8.8`: pass.
  - Project image SteamCMD login/app-info/update: inconclusive/failing.
  - Upstream SteamCMD login/app-info: inconclusive/failing.
  - Upstream SteamCMD with DNS override and host networking: inconclusive/failing.

## Latest Working Commands

```powershell
docker version
git init
docker compose build
docker compose up
docker compose run --rm conan gosu conan env HOME=/serverdata/steam steamcmd +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +quit
docker compose run --rm conan gosu conan env HOME=/serverdata/steam /scripts/update-server.sh
.\tests\steamcmd-connectivity.ps1
bash tests/steamcmd-connectivity.sh --skip-app-update-attempt --skip-host-network
git remote -v
git push -u origin main
```

GitHub automation preference when repo creation is needed and `gh` is available:

```powershell
gh repo create bryans1981/ConanExilesContainer --private --source . --remote origin --push
```

If `gh` is unavailable, try authenticated git/Git Credential Manager and connector/API paths before giving manual instructions.

## Important Decisions Made

- Use SteamCMD first.
- Use `steamcmd/steamcmd:ubuntu-24` as the base image.
- Seed the persistent Steam home to make non-root SteamCMD startup work.
- Explicitly request Linux platform files.
- Do not add Wine in MVP.
- Fail loudly when native Linux executable verification fails.
- Keep 8080 reserved for Phase 2 WebGUI only.
- GitHub repository work must be automation-first and private by default.
- Local Codex host is public-internet-only; do not use it for LAN/Rocky/Unraid connectivity tests.

## Files Changed In Latest Session

- `.gitignore`
- `.dockerignore`
- `.env.example`
- `.gitignore`
- `.gitattributes`
- `Dockerfile`
- `docker-compose.yml`
- `AGENTS.md`
- `PROJECT.md`
- `PROJECT_MAP.md`
- `SESSION_HANDOFF.md`
- `README.md`
- `scripts/common.sh`
- `scripts/entrypoint.sh`
- `scripts/update-server.sh`
- `scripts/configure-server.sh`
- `scripts/update-mods.sh`
- `scripts/backup.sh`
- `scripts/start-server.sh`
- `scripts/healthcheck.sh`
- `tests/steamcmd-connectivity.ps1`
- `tests/steamcmd-connectivity.sh`
- `docs/CONFIG.md`
- `docs/MODS.md`
- `docs/BACKUPS.md`
- `docs/LOCAL_DOCKER_DESKTOP.md`
- `docs/ROCKY_LINUX.md`
- `docs/TROUBLESHOOTING_STEAMCMD.md`
- `docs/WEBGUI_PHASE_2.md`

## Incomplete Work Not To Forget

- Verify downloaded server file layout.
- Verify exact config keys and paths.
- Verify modlist path/content format with real mods.
- Verify server launch syntax.
- Run the full local Docker Desktop test checklist.
- Retest SteamCMD anonymous login later; current diagnostics isolate failure to SteamCMD/Steam protocol behavior from containers or a temporary Steam-side issue.
