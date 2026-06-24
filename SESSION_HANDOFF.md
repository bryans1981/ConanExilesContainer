# Session Handoff

## Current Git/GitHub State

- Current branch: `main`
- Remote name: `origin`
- Remote URL: `https://github.com/bryans1981/ConanExilesContainer.git`
- GitHub visibility: private
- Latest baseline commit before this pass: `4c99bb7 Add LAN server listing diagnostics`
- Initial scaffold commit: `9ae5a6f Initial Conan Exiles container scaffold`
- Commit planned for this pass: `Fix local live env config application`
- GitHub automation blockers: none currently. `gh` is unavailable, but authenticated git/Git Credential Manager/API paths have worked for this repository.

## Current Live Test Status

Do not move to Rocky Linux yet. Do not start WebGUI work yet.

The user confirmed direct LAN connection from another system to the Windows Docker host worked, but the server allowed entry without the expected server password. That means basic LAN/game-port traffic is working and the main blocker shifted to config application.

The local Docker Desktop live server was rebuilt/restarted after the config fix and is running for retest.

- Server name configured in local env/config: `WickedServerContianer`
- Local env file: `.env.local-live`
- Env file status: ignored by git and excluded from Docker build context.
- Server download backend: `depotdownloader`
- Workshop mod backend: `depotdownloader`
- Workshop mods for this live run: none configured.
- Container: `conan-exiles-container`
- Current container ID prefix after restart: `0d172bef66ff`
- Container status: running and healthy after restart.
- Readiness: `StartPlay` found in recent compose logs.
- Windows host LAN IPv4 found: `10.0.0.103/24` on `Ethernet 4`
- Password values: stored only in ignored `.env.local-live` and generated local config; not committed.
- Password leak check: no env password values found in recent Docker logs.
- Current state: left running so the user can retest direct LAN connect and password prompt behavior from the other Conan Exiles client.

Do not claim password protection, browser listing, password acceptance, or live login success until the user confirms the game client result.

## Root Cause And Fix

Root cause found:

- `.env.local-live` values were reaching Docker Compose and the container environment.
- `SERVER_NAME`, `SERVER_PASSWORD`, and `ADMIN_PASSWORD` were present in the container.
- The script wrote server name/password into `ServerSettings.ini`, but the running Linux server did not consume those keys for the startup report/password behavior.
- Before the fix, `Engine.ini` section `[OnlineSubsystem]` had no `ServerName` and no `ServerPassword`.

Fix implemented:

- `scripts/configure-server.sh` now writes managed keys:
  - `Engine.ini` / `[OnlineSubsystem]` / `ServerName`
  - `Engine.ini` / `[OnlineSubsystem]` / `ServerPassword`
- Existing `ServerSettings.ini` managed keys are still preserved and updated.
- Blank password env values mean no password; non-blank env values are written on container startup.
- Unrelated config keys are preserved.

## Work Performed This Pass

- Added active `Engine.ini` `[OnlineSubsystem]` name/password writes.
- Added `tests/local-env-effective-diagnostics.ps1`.
- Added `tests/conan-config-effective-diagnostics.ps1`.
- Updated `tests/local-lan-server-diagnostics.ps1` to fail on missing live env/config password keys, missing active config path, and default startup-report name.
- Updated `AGENTS.md`, `PROJECT.md`, `PROJECT_MAP.md`, `README.md`, `docs/CONFIG.md`, `docs/LOCAL_LIVE_TEST.md`, `docs/TROUBLESHOOTING_SERVER_LISTING.md`, and this handoff.
- Rebuilt/restarted the local live server with `docker compose --env-file .env.local-live up -d --build`.

## Validation Results This Pass

Repository baseline checks:

- `git status --short --branch`: clean at start.
- `git branch --show-current`: `main`.
- `git remote -v`: `origin https://github.com/bryans1981/ConanExilesContainer.git`.
- `git log --oneline -8`: latest baseline at start was `4c99bb7 Add LAN server listing diagnostics`.

Before-fix diagnostics:

- `tests/local-env-effective-diagnostics.ps1 -EnvFile .env.local-live`: pass; env file, Compose config, and container env all had the expected masked values.
- `tests/conan-config-effective-diagnostics.ps1 -EnvFile .env.local-live`: failed as expected because active `Engine.ini` `[OnlineSubsystem]` had missing/blank server name/password keys.

Post-fix live server validation:

- Live server rebuilt and recreated successfully.
- Readiness poll reached `StartPlay`.
- Startup report appeared after the normal delay.
- `tests/local-env-effective-diagnostics.ps1 -EnvFile .env.local-live`: pass, no warnings.
- `tests/conan-config-effective-diagnostics.ps1 -EnvFile .env.local-live`: pass, no warnings.
- `tests/local-lan-server-diagnostics.ps1 -EnvFile .env.local-live`: pass with expected warnings for missing Windows Firewall rules and RCON listener not observed.

Verified post-fix facts:

- Active config path inside the container: `/serverdata/config/ConanSandbox/Saved/Config/LinuxServer`
- Local active config path: `data\config\ConanSandbox\Saved\Config\LinuxServer`
- `Engine.ini` `[OnlineSubsystem]` `ServerName`: `WickedServerContianer`
- `Engine.ini` `[OnlineSubsystem]` `ServerPassword`: non-empty
- `ServerSettings.ini` `[ServerSettings]` `ServerPassword`: non-empty
- `ServerSettings.ini` `[ServerSettings]` `AdminPassword`: non-empty
- `Engine.ini` `[URL]` `Port`: `7777`
- `Engine.ini` `[OnlineSubsystemSteam]` `GameServerQueryPort`: `27015`
- `ServerSettings.ini` `[ServerSettings]` `PingerPort`: `7778`
- Startup report now shows `Name=WickedServerContianer`.
- SourceServerQueries still starts on `27015`.
- Docker still publishes `7777/udp`, `7778/udp`, `27015/udp`, and `25575/tcp`.
- Password leak scan passed.

Final validation completed before commit/push:

- `docker compose config --quiet`: pass.
- `docker compose --env-file .env.local-live config --quiet`: pass.
- Bash syntax checks in `ubuntu:24.04`: pass.
- PowerShell parser checks for `tests/*.ps1`: pass.
- `git diff --check`: pass with Git CRLF conversion warnings only.
- `docker compose build`: pass.
- `docker compose --env-file .env.local-live ps`: live Conan container running and healthy.
- `tests/local-env-effective-diagnostics.ps1 -EnvFile .env.local-live`: pass, no warnings.
- `tests/conan-config-effective-diagnostics.ps1 -EnvFile .env.local-live`: pass, no warnings.
- `tests/local-lan-server-diagnostics.ps1 -EnvFile .env.local-live`: pass with five warnings.
- `tests/windows-firewall-conan-rules.ps1 -EnvFile .env.local-live`: check-only pass; no firewall rules changed.
- Cleanup check for named disposable containers `gracious_grothendieck` and `stoic_lamarr`: none present.

## User Retest Checklist

From the other LAN client system:

```text
Direct connect: 10.0.0.103:7777
Steam/query favorite if supported: 10.0.0.103:27015
Server browser search: WickedServerContianer
```

Retest direct connect first:

1. Try direct connect to `10.0.0.103:7777`.
2. Confirm whether the password prompt appears.
3. Enter the configured local test password from `.env.local-live`.
4. Confirm whether the password is accepted or rejected.
5. Confirm whether character creation/login reaches the server.
6. Then search the browser for `WickedServerContianer` with Show Invalid, Show Private, and Show With Mods enabled.

Report back:

- Whether direct LAN connect now requires a password.
- Whether the configured local test password is accepted.
- Whether character creation/login works.
- Whether `WickedServerContianer` appears in the server browser.
- Any exact client error text.
- Whether connection attempts appear in Docker logs.

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

Check firewall rules without changing them:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\windows-firewall-conan-rules.ps1 -EnvFile .env.local-live
```

Apply narrow firewall rules from an Administrator PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\windows-firewall-conan-rules.ps1 -EnvFile .env.local-live -Apply
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
- Named containers `gracious_grothendieck` and `stoic_lamarr` were not present in `docker ps -a`.

## Next Recommended Steps

1. User retests direct LAN connect to `10.0.0.103:7777`.
2. Confirm whether a password prompt appears and accepts the configured local test password.
3. If password protection works, continue browser listing investigation only if `WickedServerContianer` still does not appear.
4. If password protection still does not work, inspect the latest client behavior and Docker logs from the retest.

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
