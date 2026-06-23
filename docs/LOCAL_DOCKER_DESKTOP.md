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
- AppID `443030` download is blocked because SteamCMD anonymous login fails from Docker Desktop with `FAILED (No Connection)`.
- The same Steam anonymous login failure occurs in the upstream `steamcmd/steamcmd:ubuntu-24` image, including with `--network host`.
- Full first boot through the default SteamCMD backend is blocked until SteamCMD can connect to Steam Public from this host or another Docker host.
- Full Workshop mod handling remains unverified.

External metadata checked June 23, 2026:

- SteamDB lists AppID `443030` as Windows/Linux with Linux depot `443032`: https://steamdb.info/app/443030/depots/
- SteamDB lists Linux launch executable `ConanSandbox\Binaries\Linux\ConanSandboxServer`: https://steamdb.info/app/443030/config/
