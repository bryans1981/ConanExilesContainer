# Session Handoff

## Current Git/GitHub State

- Current branch: `main`
- Remote name: `origin`
- Remote URL: `https://github.com/bryans1981/ConanExilesContainer.git`
- GitHub visibility: private
- Latest confirmed baseline before root-volume work: `3c9f5cd Add Conan Exiles image`
- Local and remote baseline check before root-volume work: `git rev-list --left-right --count HEAD...origin/main` returned `0 0`
- Commit message for this root-volume pass: `Use single root data volume`
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

- Changed `docker-compose.yml` from five subfolder bind mounts to one root bind mount: `./data:/serverdata`.
- Changed the Dockerfile volume declaration from the five subfolder volumes to `VOLUME ["/serverdata"]`.
- Updated only the README volume-related snippets/section to show the single root mount.
- Updated `docs/DOCKERHUB.md`, `PROJECT.md`, and `PROJECT_MAP.md` to reflect the root data volume model.
- Verified the entrypoint creates missing `serverfiles`, `steam`, `config`, `logs`, and `backups` subfolders and preserves existing files.
- Recreated the local live compose container with the new root mount and kept live data intact.
- Did not update `AGENTS.md`; no new permanent agent rule was needed.
- Did not delete live server data, saves, config, logs, Steam cache, mods, or backups.

## Validation Results This Pass

Repository and runtime baseline:

- `git status --short`: clean at start.
- `git branch --show-current`: `main`.
- `git remote -v`: `origin https://github.com/bryans1981/ConanExilesContainer.git`.
- Latest baseline before root-volume work: `3c9f5cd Add Conan Exiles image`.
- `docker compose ps`: live Conan container running and healthy at start.

Static/build validation:

- `docker compose config --quiet`: pass.
- `docker compose --env-file .env config --quiet`: pass.
- `docker compose --env-file .env.local-live config --quiet`: pass.
- `scripts/dockerhub-build-push.ps1` parser check: pass.
- `bash -n scripts/entrypoint.sh` and `bash -n scripts/common.sh`: pass.
- `git diff --check`: pass with expected Git CRLF conversion warnings only.
- `docker compose build`: pass.

Root-volume smoke validation:

- Disposable smoke path: ignored `test-results/volume-root-smoke-*`.
- Command shape: `docker run --rm -v <disposable-data>:/serverdata conan-exiles-container:local bash -lc ...`.
- Result: pass.
- Verified `serverfiles`, `steam`, `config`, `logs`, and `backups` are created when missing.
- Verified an existing `config/sentinel.txt` file is preserved.
- Verified the SteamCMD home seed is populated under the root-mounted `steam` folder.
- Cleanup: disposable smoke folder removed.

Local live root-volume validation:

- Command run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\local-durability.ps1 -EnvFile .env.local-live -Quick -KeepRunning -SkipClientReminder`
- Result: pass, `failures=0 warnings=0`.
- Before durability, `docker compose --env-file .env.local-live up -d` recreated the container with the new single root mount.
- Verified Docker mount: `D:\Git Local\ConanExilesContainer\data -> /serverdata`.
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

Docker Hub image is available at:

```text
docker.io/bryans1981/conanexilescontainer
```

Pushed tags from the previous publish:

- `bryans1981/conanexilescontainer:latest`
- `bryans1981/conanexilescontainer:<short-git-sha>`

Publish status on June 24, 2026:

- Docker Hub authentication was present in Docker Desktop's credential helper.
- `git status --short --branch`: clean, `main...origin/main`.
- `git log --oneline -5`: latest commit before republish was `4f827cb Set backup on stop default`.
- `docker info`: Docker Desktop reachable, client/server `29.4.2`, context `desktop-linux`, builtin seccomp.
- Docker CLI config exists and uses credential store `desktop`.
- `docker-credential-desktop list`: helper available with Docker Hub/index.docker.io entries.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dockerhub-build-push.ps1 -Push`: pass.
- Pull verification command: `docker pull bryans1981/conanexilescontainer:latest`.
- Pull verification result: pass; Docker reported `Status: Image is up to date for bryans1981/conanexilescontainer:latest`.
- Docker Hub repository overview update: pass; Docker Hub API readback showed `full_description` exactly matches local `README.md` and the short description is set.

Root-volume publish status:

- `scripts/dockerhub-build-push.ps1 -Push` was run after changing the image to `VOLUME ["/serverdata"]`.
- Docker Hub push completed for `latest` and the short Git SHA tag current at publish time.
- `docker pull bryans1981/conanexilescontainer:latest` passed after the root-volume publish.
- `docker image inspect bryans1981/conanexilescontainer:latest --format '{{json .Config.Volumes}}'` returned `{"/serverdata":{}}`.

Next step: set up Unraid using the Docker Hub image, mapped ports, one root `/serverdata` volume, and UI environment variable overrides.

## Important Decisions

- Use native Linux dedicated server files.
- Do not switch to Wine.
- DepotDownloader remains the default server and Workshop download backend.
- SteamCMD remains available as an explicit backend for hosts where it works.
- Keep `seccomp=unconfined` diagnostic/emergency-only.
- Keep the committed `.env` safe and generic.
- Use ignored local env files for live tests and real passwords.
- Do not commit generated `data/`, private logs, saves, backups, local live env files, or diagnostic `test-results/`.
- Docker Hub publishing is complete; Unraid setup follows.
- Rocky Linux remains skipped until its ports are open.

## Next Recommended Steps

1. Set up Unraid using `bryans1981/conanexilescontainer:latest`.
2. Map ports `7777/udp`, `7778/udp`, `27015/udp`, and `25575/tcp` if RCON is enabled.
3. Map one persistent root data path to `/serverdata`; the container creates `serverfiles`, `steam`, `config`, `logs`, and `backups` when missing.
4. Set environment variables in the Unraid UI without committing secrets.
