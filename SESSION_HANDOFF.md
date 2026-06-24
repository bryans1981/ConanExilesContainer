# Session Handoff

## Current Git/GitHub State

- Current branch: `main`
- Remote name: `origin`
- Remote URL: `https://github.com/bryans1981/ConanExilesContainer.git`
- GitHub visibility: private
- Latest baseline commit before this pass: `c0c4d1d Add local live server test workflow`
- Initial scaffold commit: `9ae5a6f Initial Conan Exiles container scaffold`
- Commit planned for this pass: `Add LAN server listing diagnostics`
- GitHub automation blockers: none currently. `gh` is unavailable, but authenticated git/Git Credential Manager/API paths have worked for this repository.

## Current Live Test Status

Do not move to Rocky Linux yet. Do not start WebGUI work yet.

The local Docker Desktop live server is running for Conan Exiles client testing from another LAN system.

- Server name configured in local env/config: `WickedServerContianer`
- Local env file: `.env.local-live`
- Env file status: ignored by git and excluded from Docker build context.
- Server download backend: `depotdownloader`
- Workshop mod backend: `depotdownloader`
- Workshop mods for this live run: none configured.
- Container: `conan-exiles-container`
- Container status: running and healthy after restart.
- Readiness: `StartPlay` found in recent compose logs.
- Windows host LAN IPv4 found: `10.0.0.103/24` on `Ethernet 4`
- Password values: stored only in ignored `.env.local-live` and generated local config; not committed.
- Password leak check: no env password values found in recent Docker logs.
- Current state: left running so the user can attempt direct LAN connect and server-browser testing from the other Conan Exiles client.

Do not claim browser listing, direct LAN connection, password acceptance, or live login success until the user confirms the game client result.

## Work Performed This Pass

- Added explicit query-port launch support with `FORCE_QUERY_PORT_ARG=true` default.
- Added optional diagnostic launch env vars `MULTIHOME_IP` and `MULTIHOME_HTTP_IP`.
- Updated `scripts/start-server.sh` to log redacted launch arguments and launch with `-QueryPort=<QUERY_PORT>` by default.
- Created `tests/windows-firewall-conan-rules.ps1`.
- Created `tests/local-lan-server-diagnostics.ps1`.
- Added `docs/TROUBLESHOOTING_SERVER_LISTING.md`.
- Updated `docs/LOCAL_LIVE_TEST.md`, `docs/CONFIG.md`, `README.md`, `PROJECT.md`, `PROJECT_MAP.md`, `AGENTS.md`, and this handoff.
- Restarted/rebuilt the local live container after launch/env changes.

## Validation Results This Pass

Repository baseline checks:

- `git status --short --branch`: worktree was dirty with in-progress LAN diagnostics edits when this resumed; changes were inspected before continuing.
- `git branch --show-current`: `main`.
- `git remote -v`: `origin https://github.com/bryans1981/ConanExilesContainer.git`.
- `git log --oneline -5`: latest baseline at start was `c0c4d1d Add local live server test workflow`.

Static validation already passed before the final doc updates:

- Bash syntax checks in `ubuntu:24.04`: pass.
- PowerShell parser checks for `tests/*.ps1`: pass.
- `git diff --check`: pass.
- `docker compose --env-file .env.local-live up -d --build`: pass.

Live LAN diagnostics after restart:

- `docker compose --env-file .env.local-live ps`: container running and healthy.
- Docker-published ports:
  - `7777/udp -> 0.0.0.0:7777`
  - `7778/udp -> 0.0.0.0:7778`
  - `27015/udp -> 0.0.0.0:27015`
  - `25575/tcp -> 0.0.0.0:25575`
- In-container listeners:
  - `7777/udp`: observed.
  - `7778/udp`: observed after query/pinger startup completed.
  - `27015/udp`: observed after SourceServerQueries startup completed.
  - `25575/tcp`: Docker-published, but not observed listening inside the container during this pass.
- Host port owners:
  - UDP `7777`, `7778`, and `27015`: `com.docker.backend`.
  - TCP `25575`: `wslrelay` and `com.docker.backend`.
- Windows Firewall:
  - No specific inbound allow rule found for UDP `7777`.
  - No specific inbound allow rule found for UDP `7778`.
  - No specific inbound allow rule found for UDP `27015`.
  - No specific inbound allow rule found for TCP `25575`.
- Old host process candidates:
  - No old Conan, Dedicated Server Launcher, or host SteamCMD process candidates found.
- Log readiness/listing clues:
  - `StartPlay` found.
  - `LogInit: Command Line: -log -QueryPort=27015`.
  - `Created socket for bind address: 0.0.0.0:7777`.
  - `IpNetDriver listening on port 7777`.
  - `SourceServerQueries` started on port `27015`.
  - `Autologin attempt failed, unable to register server!`.
  - `SteamSockets: Disabled due to no Steam OSS running.`
  - Startup report still showed `Name=Conan Exiles Server` even though generated local config contains `ServerName=WickedServerContianer`.
- `tests/local-lan-server-diagnostics.ps1 -EnvFile .env.local-live`: pass with warnings for missing firewall rules and RCON listener not observed.
- `tests/windows-firewall-conan-rules.ps1 -EnvFile .env.local-live`: check-only pass; all four named rules reported missing; no firewall changes made.

Final validation completed before commit/push:

- `docker compose config --quiet`: pass.
- `docker compose --env-file .env.local-live config --quiet`: pass.
- Bash syntax checks in `ubuntu:24.04`: pass.
- PowerShell parser checks for `tests/*.ps1`: pass.
- `git diff --check`: pass with Git CRLF conversion warnings only.
- `docker compose build`: pass.
- `docker compose --env-file .env.local-live ps`: live Conan container running and healthy.
- `tests/local-lan-server-diagnostics.ps1 -EnvFile .env.local-live`: pass with five warnings.
- `tests/windows-firewall-conan-rules.ps1 -EnvFile .env.local-live`: check-only pass; no firewall rules changed.
- Password leak scan through the LAN diagnostic helper: pass.

## User Connection Checklist

From the other LAN client system:

```text
Direct connect: 10.0.0.103:7777
Steam/query favorite if supported: 10.0.0.103:27015
Server browser search: WickedServerContianer
```

Enable:

- Show Invalid
- Show Private
- Show With Mods

Use the local test password from `.env.local-live`.

Report back:

- Whether direct connect to `10.0.0.103:7777` works.
- Whether query/favorite entry with `10.0.0.103:27015` works, if supported.
- Whether `WickedServerContianer` appears in the server browser.
- Whether the password prompt appears.
- Whether the password is accepted.
- Whether character creation/login reaches the server.
- Any exact client error text.
- Whether connection attempts appear in Docker logs.

## Live Server Commands

View status:

```powershell
docker compose --env-file .env.local-live ps
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
- Named containers `gracious_grothendieck` and `stoic_lamarr` were not present in `docker ps -a`, so no removal was needed.
- An unrelated `secondagerevival-webclient` container was observed and not touched because it is outside this repo and was not one of the named cleanup targets.
- Ignored `.env.local-live` and `./data` remain local and untracked.

## Next Recommended Steps

1. If direct LAN connect fails, apply the narrow Windows Firewall rules from Administrator PowerShell and retest.
2. From the other LAN client, try direct connect to `10.0.0.103:7777`.
3. If supported, try the query/favorite target `10.0.0.103:27015`.
4. Search the server browser for `WickedServerContianer` with Show Invalid, Show Private, and Show With Mods enabled.
5. Report exact client behavior and any errors.
6. If direct connect works but browser listing still fails, continue investigating the registration warning, SteamSockets warning, and startup-report name mismatch.

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
