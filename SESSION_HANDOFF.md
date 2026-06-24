# Session Handoff

## Current Git/GitHub State

- Current branch: `main`
- Remote name: `origin`
- Remote URL: `https://github.com/bryans1981/ConanExilesContainer.git`
- GitHub visibility: private
- Latest confirmed baseline before Docker Hub publish attempt: `52d2bfd Add local durability and Docker Hub workflow`
- Local and remote baseline check before publish attempt: `git status --short --branch` returned `## main...origin/main`
- Commit message for this handoff/status update: `Publish Docker Hub image`
- GitHub automation blockers: none currently. `gh` is unavailable, but authenticated git/Git Credential Manager/API paths have worked for this repository.

## Current Live Server Status

Do not move to Rocky Linux yet. Rocky ports are not open, so Rocky remains skipped.

The user previously confirmed from another LAN Conan Exiles client that the local Docker Desktop server can be seen, login works, the server name is correct, the server password works, the admin password works, and the client shows the corrected America/North America region.

- Live server env file: `.env.local-live`
- Env file status: ignored by git and excluded from Docker build context.
- Container: `conan-exiles-container`
- Container ID prefix during durability run: `677d2b6596ca`
- Container state after durability validation: running and healthy.
- Live server data: not deleted.
- Durability helper left the service running with `-KeepRunning`.
- Password values: stored only in ignored `.env.local-live` and generated local config; not committed.

Use `docker compose --env-file .env.local-live ...` for continued live-server work. Running plain `docker compose up -d` uses the committed safe `.env` defaults and may recreate the service with generic non-password settings.

## Work Performed This Pass

- Added `tests/local-durability.ps1` as the primary Docker Desktop Windows Step 4 durability helper.
- Added optional `tests/local-durability.sh` for compatible Bash environments.
- Added `scripts/dockerhub-build-push.ps1` for Docker Hub dry-run, build/tag, and explicit `-Push` publishing.
- Added `docs/DOCKERHUB.md` with target repository, dry-run/build/push commands, tag plan, and post-publish compose example.
- Updated `README.md` with the local durability command and a planned/ready Docker Hub image section without claiming the image has been pushed.
- Updated `docs/LOCAL_DOCKER_DESKTOP.md` and `docs/LOCAL_LIVE_TEST.md` with durability workflow notes.
- Updated `PROJECT.md` and `PROJECT_MAP.md` so the next target order is local durability, Docker Hub publish, Unraid after publish, then Rocky later after ports are open.
- Did not update `AGENTS.md`; no new permanent agent rule was needed.
- Did not publish to Docker Hub.
- Did not delete live server data, saves, config, logs, Steam cache, mods, or backups.

## Validation Results This Pass

Repository and runtime baseline:

- `git status --short`: clean at start.
- `git branch --show-current`: `main`.
- `git remote -v`: `origin https://github.com/bryans1981/ConanExilesContainer.git`.
- `git log --oneline -8`: latest baseline was `a08296e Add safe env defaults and clean README`.
- `docker compose ps`: live Conan container running and healthy at start.

Static/build validation:

- `docker compose config --quiet`: pass.
- `docker compose --env-file .env config --quiet`: pass.
- `docker compose --env-file .env.local-live config --quiet`: pass.
- PowerShell parser checks for `tests/*.ps1` and `scripts/*.ps1`: pass, 11 scripts parsed.
- Bash syntax checks for `scripts/*.sh` and `tests/*.sh`: pass, 13 scripts checked.
- `git diff --check`: pass with expected Git CRLF conversion warnings only.
- `docker compose build`: pass.
- `scripts/dockerhub-build-push.ps1` dry run: pass before and after local commit, no push attempted.

Local durability validation:

- Command run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\local-durability.ps1 -EnvFile .env.local-live -Quick -KeepRunning -SkipClientReminder`
- Result: pass, `failures=0 warnings=0`.
- Verified compose config with default `.env` and `.env.local-live`.
- Verified current container was running before the test.
- Verified `StartPlay` readiness before and after graceful restart.
- Verified active config path: `/serverdata/config/ConanSandbox/Saved/Config/LinuxServer`.
- Verified host persistent config path: `data\config\ConanSandbox\Saved\Config\LinuxServer`.
- Verified live `SERVER_NAME` applied without printing passwords.
- Verified `SERVER_REGION=America` resolved to `serverRegion=1`.
- Verified non-empty server and admin password keys without printing values.
- Verified published ports: `7777/udp`, `7778/udp`, `27015/udp`, and RCON `25575/tcp` because RCON is enabled in the ignored live env.
- Verified config directory persisted after restart.
- Verified saved directory persisted after restart.
- Verified a new backup archive was created: `data\backups\conan-backup-20260624T021151Z-durability.tar.gz`.
- Verified `UPDATE_SERVER_ON_START` restart path did not wipe config or saves.
- Verified `ConanSandbox/Mods/modlist.txt` exists and entries point to files.
- Verified no `.env.local-live` password values appeared in Docker logs, retained logs, or tracked files.
- Final compose status after durability run: running and healthy.

Safety and cleanup:

- Tracked secret scan against non-empty local live `SERVER_PASSWORD`, `ADMIN_PASSWORD`, and `RCON_PASSWORD`: pass.
- No disposable temp artifacts were left.
- The new durability backup archive was left in ignored live `data/backups` as useful proof and normal server backup data.
- No live data was removed.

## Docker Hub Status

Docker Hub publishing workflow is prepared for:

```text
docker.io/bryans1981/conanexilescontainer
```

Prepared tags:

- `bryans1981/conanexilescontainer:latest`
- `bryans1981/conanexilescontainer:<short-git-sha>`

Publish attempt status on June 24, 2026:

- Blocked before push because Docker Hub authentication was not present.
- `git status --short --branch`: clean, `main...origin/main`.
- `git log --oneline -5`: latest commit was `52d2bfd Add local durability and Docker Hub workflow`.
- `docker info`: Docker Desktop reachable, client/server `29.4.2`, context `desktop-linux`, builtin seccomp.
- `docker compose build`: pass.
- Docker CLI config exists and uses credential store `desktop`.
- `docker-credential-desktop list`: helper available with one stored credential entry, but no Docker Hub/index.docker.io entry.
- Because Docker Hub login/auth was missing, `scripts/dockerhub-build-push.ps1 -Push` was not run and no image was pushed.
- Pull verification was not run because no push occurred.

Required next manual step: run `docker login docker.io` with the intended Docker Hub account, then retry `scripts/dockerhub-build-push.ps1 -Push`. Do not print Docker Hub credentials or tokens.

## Important Decisions

- Use native Linux dedicated server files.
- Do not switch to Wine.
- DepotDownloader remains the default server and Workshop download backend.
- SteamCMD remains available as an explicit backend for hosts where it works.
- Keep `seccomp=unconfined` diagnostic/emergency-only.
- Keep the committed `.env` safe and generic.
- Use ignored local env files for live tests and real passwords.
- Do not commit generated `data/`, private logs, saves, backups, local live env files, or diagnostic `test-results/`.
- Docker Hub is next after local durability; Unraid follows Docker Hub publish.
- Rocky Linux remains skipped until its ports are open.

## Next Recommended Steps

1. Log in to Docker Hub with `docker login docker.io` for an account that can push `bryans1981/conanexilescontainer`.
2. Retry `scripts/dockerhub-build-push.ps1 -Push`.
3. Verify pull with `docker pull bryans1981/conanexilescontainer:latest`.
4. After a successful push and pull verification, update `README.md`, `docs/DOCKERHUB.md`, and this handoff with the pushed tags and pull result.
5. Set up Unraid using the Docker Hub image, mapped ports/volumes, and UI environment variable overrides.
