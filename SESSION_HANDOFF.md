# Session Handoff

## Current Git/GitHub State

- Current branch: `main`
- Remote name: `origin`
- Remote URL: `https://github.com/bryans1981/ConanExilesContainer.git`
- GitHub visibility: private
- Latest baseline commit before this pass: `1c434a3 Fix local live env config application`
- Initial scaffold commit: `9ae5a6f Initial Conan Exiles container scaffold`
- Commit planned for this pass: `Set local live server region`
- GitHub automation blockers: none currently. `gh` is unavailable, but authenticated git/Git Credential Manager/API paths have worked for this repository.

## Current Live Test Status

Do not move to Rocky Linux yet. Do not start WebGUI work yet.

The user confirmed from another LAN Conan Exiles client that the server login works, the server name is correct, and passwords work. The user then reported the browser/list region showed EU while it should show America.

The local Docker Desktop live server was rebuilt/restarted after the region fix and is running for retest.

- Server name configured in local env/config: `WickedServerContianer`
- Local env file: `.env.local-live`
- Env file status: ignored by git and excluded from Docker build context.
- Server download backend: `depotdownloader`
- Workshop mod backend: `depotdownloader`
- Workshop mods for this live run: none configured.
- Container: `conan-exiles-container`
- Current container ID prefix after restart: `677d2b6596ca`
- Container status: running and healthy after restart.
- Readiness: `StartPlay` found in recent compose logs.
- Startup report after region fix: `Name=WickedServerContianer`, `Region=1`, `QueryPort=27015`.
- Windows host LAN IPv4 found: `10.0.0.103/24` on `Ethernet 4`
- Password values: stored only in ignored `.env.local-live` and generated local config; not committed.
- Password leak check: no env password values found in recent Docker logs.
- Current state: left running so the user can retest whether the client/browser now shows America/North America instead of EU.

Do not claim the client-facing region display is fixed until the user confirms it from the Conan Exiles client.

## Region Mapping

The live server previously had `serverRegion=0`, and the user observed EU in the client.

Verified mapping from the Windows Dedicated Server Launcher strings and an old launcher backup:

- `0`: Europe
- `1`: North America
- `2`: Asia
- `3`: Australia
- `4`: South America
- `5`: Japan

Fix implemented:

- Added `SERVER_REGION=1` default to the image, compose environment, and `.env.example`.
- Added `SERVER_REGION=1` to ignored `.env.local-live`.
- `scripts/configure-server.sh` now validates `SERVER_REGION` is `0..5`.
- `scripts/configure-server.sh` writes `ServerSettings.ini` / `[ServerSettings]` / `serverRegion`.
- Env/config/LAN diagnostics now check region value and startup-report region.

## Work Performed This Pass

- Added `SERVER_REGION` support.
- Updated `.env.example`, `Dockerfile`, `docker-compose.yml`, and ignored `.env.local-live`.
- Updated `scripts/configure-server.sh`.
- Updated `tests/local-env-effective-diagnostics.ps1`.
- Updated `tests/conan-config-effective-diagnostics.ps1`.
- Updated `tests/local-lan-server-diagnostics.ps1`.
- Updated `PROJECT.md`, `PROJECT_MAP.md`, `README.md`, `docs/CONFIG.md`, `docs/LOCAL_LIVE_TEST.md`, and this handoff.
- Rebuilt/restarted the local live server with `docker compose --env-file .env.local-live up -d --build`.

## Validation Results This Pass

Repository baseline checks:

- `git status --short --branch`: clean at start.
- `git log --oneline -5`: latest baseline at start was `1c434a3 Fix local live env config application`.
- `docker compose --env-file .env.local-live ps`: live server running and healthy before changes.

Region evidence before fix:

- Active config had `serverRegion=0`.
- Startup report showed `Region=0`.
- User reported the client showed EU.

Post-fix live server validation:

- Live server rebuilt and recreated successfully.
- Readiness poll reached `StartPlay`.
- Startup report appeared after the normal delay.
- Startup report showed `Region=1`.
- `tests/local-env-effective-diagnostics.ps1 -EnvFile .env.local-live`: pass, no warnings.
- `tests/conan-config-effective-diagnostics.ps1 -EnvFile .env.local-live`: pass, no warnings.
- `tests/local-lan-server-diagnostics.ps1 -EnvFile .env.local-live`: pass with warnings for missing specific Windows Firewall rules, RCON listener not observed, and one host-side UDP 7778 endpoint visibility warning. In-container UDP `7778` was observed.
- `tests/windows-firewall-conan-rules.ps1 -EnvFile .env.local-live`: check-only pass; no firewall rules changed.

Verified post-fix facts:

- `.env.local-live`: `SERVER_REGION=1`.
- Container env: `SERVER_REGION=1`.
- Active config path inside the container: `/serverdata/config/ConanSandbox/Saved/Config/LinuxServer`
- Local active config path: `data\config\ConanSandbox\Saved\Config\LinuxServer`
- `ServerSettings.ini` `[ServerSettings]` `serverRegion`: `1`.
- Startup report: `Region=1`.
- `Engine.ini` `[OnlineSubsystem]` `ServerName`: `WickedServerContianer`
- `Engine.ini` `[OnlineSubsystem]` `ServerPassword`: non-empty.
- `ServerSettings.ini` `[ServerSettings]` `AdminPassword`: non-empty.
- Docker publishes `7777/udp`, `7778/udp`, `27015/udp`, and `25575/tcp`.
- Password leak scan passed.

Final validation completed before commit/push:

- `docker compose config --quiet`: pass.
- `docker compose --env-file .env.local-live config --quiet`: pass.
- Bash syntax checks in `ubuntu:24.04`: pass.
- PowerShell parser checks for `tests/*.ps1`: pass.
- `git diff --check`: pass with Git CRLF conversion warnings only.
- Secret string scan outside ignored local env/data/test-results: no matches.
- `docker compose build`: pass.
- `docker compose --env-file .env.local-live ps`: live Conan container running and healthy.
- `tests/local-env-effective-diagnostics.ps1 -EnvFile .env.local-live`: pass, no warnings.
- `tests/conan-config-effective-diagnostics.ps1 -EnvFile .env.local-live`: pass, no warnings.
- `tests/local-lan-server-diagnostics.ps1 -EnvFile .env.local-live`: pass with six warnings for missing specific Windows Firewall rules, RCON listener not observed, and one host-side UDP 7778 endpoint visibility warning. In-container UDP `7778` was observed.
- `tests/windows-firewall-conan-rules.ps1 -EnvFile .env.local-live`: check-only pass; no firewall rules changed.

## User Retest Checklist

From the other LAN client system:

```text
Direct connect: 10.0.0.103:7777
Steam/query favorite if supported: 10.0.0.103:27015
Server browser search: WickedServerContianer
```

Report back:

- Whether the server region now shows America/North America instead of EU.
- Whether direct LAN login still works.
- Whether passwords still behave correctly.
- Whether `WickedServerContianer` appears in the server browser.
- Any exact client error text.

## Live Server Commands

View status:

```powershell
docker compose --env-file .env.local-live ps
```

Run env/config diagnostics:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\local-env-effective-diagnostics.ps1 -EnvFile .env.local-live
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\conan-config-effective-diagnostics.ps1 -EnvFile .env.local-live
```

Run LAN diagnostics:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\local-lan-server-diagnostics.ps1 -EnvFile .env.local-live
```

Follow logs while testing:

```powershell
docker compose --env-file .env.local-live logs -f --tail 200 conan
```

Stop without deleting data:

```powershell
docker compose --env-file .env.local-live stop
```

Restart without wiping data:

```powershell
docker compose --env-file .env.local-live up -d
```

Remove the container while keeping `./data`:

```powershell
docker compose --env-file .env.local-live down
```

Do not delete `./data` during this live test unless the user explicitly wants to wipe local server files, saves, config, logs, Steam cache, mods, and backups.

## Cleanup Status

- Live server data was not deleted.
- Live config, logs, backups, server files, and saves were not removed.
- The live Conan container was intentionally left running.
- Ignored `.env.local-live` and `./data` remain local and untracked.
- No disposable test containers were intentionally left behind by this pass.

## Next Recommended Steps

1. User retests from the Conan Exiles client and confirms whether the region now shows America/North America.
2. If the client still shows EU despite `Region=1` in logs, inspect whether the client cached listing metadata or whether another region/display key is involved.

## Important Decisions

- Use native Linux dedicated server files.
- Do not switch to Wine.
- DepotDownloader is the default server and Workshop download backend for this project.
- SteamCMD remains available as an explicit backend for hosts where it works.
- Keep `seccomp=unconfined` diagnostic/emergency-only.
- Use ignored local env files for live tests.
- Do not commit real local test passwords or generated live server data.
- Do not print tokens, passwords, or secrets.
- Keep GitHub repository work automation-first and private by default.
