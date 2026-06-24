# Session Handoff

## Current Git/GitHub State

- Current branch: `main`
- Remote name: `origin`
- Remote URL: `https://github.com/bryans1981/ConanExilesContainer.git`
- GitHub visibility: private
- Latest pushed commit before this pass: `f7591e46b6f760042e954f5c572b8e9112ef991e Finalize safe downloader backend defaults`
- Initial scaffold commit: `9ae5a6f Initial Conan Exiles container scaffold`
- Commit planned for this pass: `Add local live server test workflow`
- GitHub automation blockers: none currently. `gh` is unavailable, but authenticated git/Git Credential Manager/API paths have worked for this repository.

## Current Live Test Status

Do not move to Rocky Linux yet. Do not start WebGUI work yet.

The local Docker Desktop live server is running for Conan Exiles client testing.

- Server name: `WickedServerContianer`
- Local env file: `.env.local-live`
- Env file status: ignored by git and excluded from Docker build context.
- Server download backend: `depotdownloader`
- Workshop mod backend: `depotdownloader`
- Workshop mods for this live run: none configured.
- Container: `conan-exiles-container`
- Container status: running and healthy after startup.
- Readiness: `StartPlay` found in recent compose logs.
- Password values: stored only in ignored `.env.local-live` and generated local config; not committed.
- Password leak check: no env password values found in recent Docker logs or retained server logs.
- Current state: left running so the user can attempt live login from the Conan Exiles client.

Do not claim live client success until the user confirms the game client can connect and enter the server.

## User Connection Checklist

Try the in-game server browser first:

```text
WickedServerContianer
```

If direct connect is available, try:

```text
127.0.0.1:7777
localhost:7777
<host-lan-ip>:7777
```

Use the local test password from `.env.local-live`.

Query port:

```text
27015
```

If connecting from another LAN machine, use the Windows host LAN IP instead of `127.0.0.1` or `localhost`.

Report back:

- Whether `WickedServerContianer` appears in the server browser.
- Whether direct connect works.
- Whether the password is accepted.
- Whether character creation/login reaches the server.
- Any exact client error text.
- Whether connection attempts appear in Docker logs.

## Live Server Commands

View status:

```powershell
docker compose --env-file .env.local-live ps
```

Run the status helper:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\local-live-status.ps1 -EnvFile .env.local-live
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

## Work Performed This Pass

- Added `.env.local`, `.env.local-live`, and `.env.test-live` to `.gitignore` and `.dockerignore`.
- Created ignored local live env file `.env.local-live` with the requested local test settings.
- Added `docs/LOCAL_LIVE_TEST.md`.
- Added `tests/local-live-status.ps1`.
- Updated `AGENTS.md`, `PROJECT.md`, `PROJECT_MAP.md`, `README.md`, `docs/LOCAL_DOCKER_DESKTOP.md`, and this handoff.
- Started the local live server with `docker compose --env-file .env.local-live up -d --build`.

## Validation Results This Pass

Repository baseline checks:

- `git status --short --branch`: clean at start.
- `git branch --show-current`: `main`.
- `git remote -v`: `origin https://github.com/bryans1981/ConanExilesContainer.git`.
- `git log --oneline -5`: latest at start was `f7591e4 Finalize safe downloader backend defaults`.

Ignore checks:

- `git check-ignore -v .env.local-live`: pass; `.env.local-live` is ignored by `.gitignore`.

Static validation:

- `docker compose config --quiet`: pass.
- `docker compose --env-file .env.local-live config --quiet`: pass.
- Bash syntax checks in `ubuntu:24.04`: pass.
- PowerShell parser checks for `tests/*.ps1`: pass.
- `git diff --check`: pass with only Git CRLF conversion warnings.
- `docker compose build`: pass.

Live server validation:

- `docker compose --env-file .env.local-live up -d --build`: pass.
- `docker compose --env-file .env.local-live ps`: container running, ports published, health became healthy.
- Readiness poll: `StartPlay` found.
- `tests/local-live-status.ps1 -EnvFile .env.local-live`: pass.
- Published ports:
  - `7777/udp -> 0.0.0.0:7777`
  - `7778/udp -> 0.0.0.0:7778`
  - `27015/udp -> 0.0.0.0:27015`
  - `25575/tcp -> 0.0.0.0:25575`
- Recent fatal-pattern scan: pass.
- Password leak scan: pass.
- Local data usage at status check:
  - `serverfiles=4.40 GiB`
  - `steam=195.18 MiB`
  - `config=6.52 KiB`
  - `logs=197.82 KiB`
  - `backups=1.77 KiB`

## SteamCMD Blocker Status

SteamCMD remains blocked under Docker Desktop default security on this host. This live server uses DepotDownloader defaults and does not use `seccomp=unconfined`.

Known facts:

- Windows host SteamCMD works from `C:\Conan Exiles Server\DedicatedServerLauncher\steamcmd.exe`.
- Linux SteamCMD fails under Docker Engine `29.4.2` builtin seccomp in both the project image and upstream `steamcmd/steamcmd:ubuntu-24`.
- Linux SteamCMD passes when run with diagnostic `seccomp=unconfined`.
- `docker-compose.steamcmd-unconfined.diagnostic.yml` remains diagnostic/emergency-only and is not part of the normal live-server path.

## Cleanup Status

- No live server data was deleted.
- No generated config, logs, backups, server files, or saves were removed.
- The live container was intentionally left running.
- No throwaway diagnostic containers are known to remain from this pass.
- Ignored `.env.local-live` and `./data` remain local and untracked.

## Next Recommended Steps

1. User attempts Conan Exiles client connection to `WickedServerContianer`.
2. If browser discovery fails, try direct connect to `127.0.0.1:7777`, `localhost:7777`, and the Windows host LAN IP on port `7777`.
3. Watch logs with `docker compose --env-file .env.local-live logs -f --tail 200 conan` during the attempt.
4. Report whether browser discovery, direct connect, password entry, and character creation/login work.
5. Keep Rocky Linux and WebGUI work paused until local live client testing is complete.

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
