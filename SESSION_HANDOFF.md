# Session Handoff

## Current Git/GitHub State

- Current branch: `main`
- Remote name: `origin`
- Remote URL: `https://github.com/bryans1981/ConanExilesContainer.git`
- GitHub visibility: private
- Latest pushed baseline before this cleanup pass: `c980c79 Update handoff after region push`
- Cleanup commit message for this pass: `Add safe env defaults and clean README`
- Initial scaffold commit: `9ae5a6f Initial Conan Exiles container scaffold`
- GitHub automation blockers: none currently. `gh` is unavailable, but authenticated git/Git Credential Manager/API paths have worked for this repository.

## Current Live Server Status

Do not move to Rocky Linux yet. Do not start WebGUI work yet.

The user confirmed from another LAN Conan Exiles client that the local Docker Desktop server can be seen, login works, the server name is correct, the server password works, the admin password works, and the client now shows the corrected America/North America region.

- Live server env file: `.env.local-live`
- Env file status: ignored by git and excluded from Docker build context.
- Container: `conan-exiles-container`
- Container ID prefix: `677d2b6596ca`
- Container state after cleanup validation: running and healthy.
- Live server data: not deleted.
- Live server image/container: not recreated during the cleanup pass.
- Server name in live test: `WickedServerContianer`
- Live startup report from existing logs: `Name=WickedServerContianer`, `Region=1`, `QueryPort=27015`.
- Password values: stored only in ignored `.env.local-live` and generated local config; not committed.

Use `docker compose --env-file .env.local-live ...` for continued live-server work. Running plain `docker compose up -d` now uses the committed safe `.env` defaults and may recreate the service with generic non-password settings.

## Work Performed This Pass

- Added a committed `.env` with safe defaults only.
- Kept `.env.example` as a complete safe template.
- Updated `.gitignore` and `.dockerignore` so `.env` is allowed while `.env.local*`, `.env.test*`, `.env.secret*`, private env files, `data/`, `test-results/`, logs, backups, and generated runtime folders stay ignored.
- Changed safe defaults to `SERVER_REGION=America` and `RCON_ENABLED=false`.
- Updated `scripts/configure-server.sh` so `SERVER_REGION` accepts readable aliases such as `America`, `NorthAmerica`, `EU`, `Japan`, and numeric `0..5`, then writes Conan's numeric `serverRegion`.
- Updated PowerShell diagnostics to normalize readable region aliases before comparing against active numeric Conan config/log values.
- Rewrote `README.md` into a shorter LinuxServer.io-style setup guide with overview, status, quick start, compose, docker run, ports, volumes, env vars, mods, backups, updating, support commands, troubleshooting links, and roadmap.
- Updated `AGENTS.md`, `PROJECT.md`, `PROJECT_MAP.md`, and docs to reflect safe `.env` defaults, confirmed local live status, and disposable diagnostic output handling.
- Kept all tracked `tests/` diagnostics because each remaining script is still useful and referenced by troubleshooting or live-test docs.
- Kept `docker-compose.steamcmd-unconfined.diagnostic.yml` because it remains documented as a SteamCMD seccomp diagnostic/emergency-only override.
- Removed ignored local `test-results/` artifacts after preserving the important proof/status in project docs and this handoff. Removed size was about 1.02 GiB.
- Did not remove `data/` or any live server files, saves, config, logs, Steam cache, mods, or backups.
- Did not remove `secondagerevival-webclient`; it is a healthy running container from another project and was not clearly a throwaway Conan diagnostic container.

## Validation Results This Pass

Repository and runtime baseline:

- `git status --short --branch`: clean at start.
- `git branch --show-current`: `main`.
- `git remote -v`: `origin https://github.com/bryans1981/ConanExilesContainer.git`.
- `git log --oneline -8`: latest baseline was `c980c79 Update handoff after region push`.
- `docker compose ps`: `conan-exiles-container` running and healthy.

Static/build validation:

- `docker compose config --quiet`: pass.
- `docker compose --env-file .env config --quiet`: pass.
- Bash syntax checks in `ubuntu:24.04`: pass.
- PowerShell parser checks for remaining `tests/*.ps1`: pass.
- `git diff --check`: pass with Git CRLF conversion warnings only.
- `docker compose build`: pass.
- Disposable no-download image smoke: `SERVER_REGION=America` writes `serverRegion=1`.

Safety checks:

- `.env` safe-default scan: pass; no live server name, no known test password string, and blank committed password variables.
- Tracked-private-artifact scan: pass; no tracked live data, `test-results`, private env files, or private logs.
- README compose example is explicitly an example and uses local `build: .`; no published registry image is claimed.
- `test-results/`: removed after validation; ignored directory no longer present.

Live-server diagnostics after script changes:

- `docker compose --env-file .env.local-live ps`: live Conan container running and healthy.
- `tests/local-env-effective-diagnostics.ps1 -EnvFile .env.local-live`: pass, no warnings.
- `tests/conan-config-effective-diagnostics.ps1 -EnvFile .env.local-live`: pass, no warnings.
- `tests/local-lan-server-diagnostics.ps1 -EnvFile .env.local-live`: pass with six known warnings for missing narrow Windows Firewall rules, RCON listener not observed, and one host-side UDP `7778` endpoint visibility warning. In-container UDP `7778` was observed.
- `tests/windows-firewall-conan-rules.ps1 -EnvFile .env.local-live`: check-only pass; no firewall rules changed.

## Important Decisions

- Use native Linux dedicated server files.
- Do not switch to Wine.
- DepotDownloader remains the default server and Workshop download backend.
- SteamCMD remains available as an explicit backend for hosts where it works.
- Keep `seccomp=unconfined` diagnostic/emergency-only.
- Keep the committed `.env` safe and generic.
- Use ignored local env files for live tests and real passwords.
- Do not commit generated `data/`, private logs, saves, backups, local live env files, or diagnostic `test-results/`.
- Keep GitHub repository work automation-first and private by default.

## Next Recommended Steps

1. Commit and push this cleanup pass.
2. Continue observing the local live server only if the user wants more Docker Desktop validation.
3. Next feature-validation targets remain multi-mod ordering/removal/pruning, longer-running behavior, Rocky Linux, and Unraid.
