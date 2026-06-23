# Session Handoff

## Current Status

Initial MVP scaffold is complete and locally validated as far as possible without Steam anonymous login. Docker Desktop is available on the local host. GitHub CLI is not installed, so the GitHub repository has not been created from this session. The local repository is initialized with git.

## Completed

- Created required project-control documents.
- Added Dockerfile, compose file, `.env.example`, `.gitignore`, `.dockerignore`, README, docs, and lifecycle scripts.
- Implemented SteamCMD install/update targeting AppID `443030`.
- Switched to the `steamcmd/steamcmd:ubuntu-24` base image and seeded `/serverdata/steam` with a bootstrapped SteamCMD home so SteamCMD can run as the configured non-root user.
- Implemented native Linux executable verification and clear failure if only Windows executables are found.
- Implemented runtime `PUID`/`PGID`, persistent directories, config/log linking, backups, mod downloads, modlist generation, and healthcheck.
- Marked `AUTO_GAME_UPDATE` and `AUTO_MOD_UPDATE` as planned/not active instead of pretending they work.
- Verified compose config, Bash syntax, Docker build, SteamCMD startup, config generation, empty modlist handling, backup creation, and no-executable failure behavior.

## In Progress

- SteamCMD verification of actual AppID `443030` server file layout.
- Full first boot after Steam anonymous login works.

## Next Recommended Steps

1. Retry SteamCMD anonymous login from this Docker Desktop host or move verification to the Rocky Linux Docker host.
2. Run `docker compose up` with empty `./data` folders once Steam login works.
3. Confirm whether AppID `443030` provides the expected native Linux executable.
4. If native files exist, verify executable name, config paths, launch syntax, and modlist behavior from downloaded files.
5. If only Windows files exist, decide whether to add a documented optional Wine fallback in a later phase.
6. Test Workshop mod download with known mod IDs.
7. Commit/push to a private GitHub repo once remote creation is available.

## Known Blockers

- `gh` is unavailable on this host, so remote GitHub repository creation must be done manually or after installing GitHub CLI.
- SteamCMD anonymous login fails from Docker Desktop with `FAILED (No Connection)`. The same failure occurs in the upstream `steamcmd/steamcmd:ubuntu-24` image and with Docker host networking.
- Native Linux server availability for AppID `443030` has not yet been proven by a completed SteamCMD install in this environment.

## Known Risks

- Config key paths and modlist behavior are implemented as expected Conan/Unreal dedicated server paths but still require verification against real downloaded server files.
- External SteamDB metadata indicates Linux support, but this is not a substitute for local downloaded-file verification.
- `EXTRA_ARGS` is split on spaces and does not support shell-style quoting.
- Background auto update loops are not active in MVP.

## Latest Test Results

- `docker version`: passed; Docker Desktop engine is available.
- `gh auth status`: failed; `gh` command is not installed.
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

## Latest Working Commands

```powershell
docker version
git init
docker compose build
docker compose up
docker compose run --rm conan gosu conan env HOME=/serverdata/steam steamcmd +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +quit
docker compose run --rm conan gosu conan env HOME=/serverdata/steam /scripts/update-server.sh
```

Manual private GitHub repo creation/push command when ready:

```powershell
git remote add origin https://github.com/<YOUR_GITHUB_USER>/ConanExilesContainer.git
git branch -M main
git push -u origin main
```

Create the repository as private before pushing. If GitHub CLI is later installed and authenticated:

```powershell
gh repo create ConanExilesContainer --private --source . --remote origin --push
```

## Important Decisions Made

- Use SteamCMD first.
- Use `steamcmd/steamcmd:ubuntu-24` as the base image.
- Seed the persistent Steam home to make non-root SteamCMD startup work.
- Explicitly request Linux platform files.
- Do not add Wine in MVP.
- Fail loudly when native Linux executable verification fails.
- Keep 8080 reserved for Phase 2 WebGUI only.

## Files Changed In Latest Session

- `.gitignore`
- `.dockerignore`
- `.env.example`
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
- `docs/CONFIG.md`
- `docs/MODS.md`
- `docs/BACKUPS.md`
- `docs/LOCAL_DOCKER_DESKTOP.md`
- `docs/ROCKY_LINUX.md`
- `docs/WEBGUI_PHASE_2.md`

## Incomplete Work Not To Forget

- Verify downloaded server file layout.
- Verify exact config keys and paths.
- Verify modlist path/content format with real mods.
- Verify server launch syntax.
- Run the full local Docker Desktop test checklist.
- Commit after validation has been recorded.
