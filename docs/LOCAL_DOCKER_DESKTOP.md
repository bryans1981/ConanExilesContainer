# Local Docker Desktop Testing

Run tests from the repository root.

## Required Commands

```powershell
docker compose build
docker compose up
```

In another terminal:

```powershell
docker compose logs -f
docker compose down
```

For live game-client testing on the local Windows host, use `docs/LOCAL_LIVE_TEST.md` instead of moving to Rocky Linux or starting WebGUI work.

## Required Checklist

- Build image locally.
- Run clean first boot with empty `./data` folders.
- Confirm server files download.
- Confirm a native Linux executable exists.
- Confirm config files are created.
- Confirm environment variables apply correctly.
- Confirm server process starts.
- Confirm graceful shutdown works.
- Confirm restart does not wipe saves/config.
- Confirm `UPDATE_SERVER_ON_START=false` skips update when files exist.
- Confirm `UPDATE_SERVER_ON_START=true` runs update.
- Confirm `WORKSHOP_MOD_IDS` downloads listed mods.
- Confirm generated mod list preserves order.
- Confirm removing a mod ID updates the active mod list.
- Confirm pruning only happens when `PRUNE_REMOVED_MODS=true`.
- Confirm backups are created before update when enabled.
- Confirm backup retention does not delete new backups.
- Confirm logs do not expose passwords.
- Confirm `AGENTS.md`, `PROJECT.md`, `PROJECT_MAP.md`, and `SESSION_HANDOFF.md` reflect current status.

## Current Local Status

- Docker Desktop engine is available.
- Docker Desktop version is `4.72.0 (225998)`.
- Docker Engine version is `29.4.2`.
- Docker security options include builtin seccomp.
- GitHub CLI is not installed.
- `docker compose config` passes.
- Bash syntax checks pass for all scripts.
- `docker compose build` passes.
- SteamCMD starts successfully from the project image using the seeded `/serverdata/steam` home.
- DepotDownloader `DepotDownloader_3.4.0` installs into the project image.
- `DOWNLOAD_BACKEND=depotdownloader` downloaded AppID `443030` successfully on June 23, 2026.
- Verified native launcher from the downloaded files: `ConanSandboxServer.sh`.
- Verified native executable from the downloaded files: `ConanSandbox/Binaries/Linux/ConanSandboxServer-Linux-Shipping`.
- Bounded launch/config probe loaded `ConanSandbox/Saved/Config/LinuxServer/ServerSettings.ini`, opened port `7777`, and reached `StartPlay`.
- Config generation/linking passes.
- Empty mod list handling passes.
- Backup creation passes.
- Start without downloaded files fails loudly with: `Cannot start: no native Linux Conan server executable found under /serverdata/serverfiles.`
- Windows host SteamCMD works from `C:\Conan Exiles Server\DedicatedServerLauncher\steamcmd.exe`.
- Linux SteamCMD under Docker default builtin seccomp fails with `CreateBoundSocket: failed to create socket, error [no name available] (38)` and `FAILED (No Connection)`.
- Linux SteamCMD under Docker diagnostic `seccomp=unconfined` succeeds for anonymous login and AppID `443030` app-info checks.
- `docker-compose.steamcmd-unconfined.diagnostic.yml` is available only as a diagnostic/emergency workaround and is less secure than default Docker isolation.
- The normal compose default is now `DOWNLOAD_BACKEND=depotdownloader` and `MOD_DOWNLOAD_BACKEND=depotdownloader`.
- Full first boot through SteamCMD remains blocked on Docker Engine `29.4.2` until Docker is upgraded or a safe seccomp profile is verified.
- Single-mod Workshop download and project modlist generation were verified under Docker default security using DepotDownloader item `3720546346`.
- Single-mod Workshop download and project modlist generation were also verified under diagnostic `seccomp=unconfined` using SteamCMD item `3720546346`.
- Clean disposable compose e2e with DepotDownloader defaults passed: server download, config generation, test password application without retained-log leaks, Workshop mod download, modlist generation, `StartPlay`, graceful shutdown, restart persistence, and backup creation.
- Local live-client workflow now uses ignored `.env.local-live` and `tests/local-live-status.ps1`.
- Remaining local checks: multi-mod ordering, mod removal/pruning, and longer-running server behavior.

External metadata checked June 23, 2026:

- SteamDB lists AppID `443030` as Windows/Linux with Linux depot `443032`: https://steamdb.info/app/443030/depots/
- SteamDB lists Linux launch executable `ConanSandbox\Binaries\Linux\ConanSandboxServer`: https://steamdb.info/app/443030/config/
