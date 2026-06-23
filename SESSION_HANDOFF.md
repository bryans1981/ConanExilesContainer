# Session Handoff

## Current Git/GitHub State

- Current branch: `main`
- Remote name: `origin`
- Remote URL: `https://github.com/bryans1981/ConanExilesContainer.git`
- GitHub visibility: private
- Latest pushed commit before this pass: `af3b08c Add SteamCMD diagnostics and local host network clarification`
- Previous pushed commit: `7d8abfa Add GitHub automation rules`
- Initial scaffold commit: `9ae5a6f Initial Conan Exiles container scaffold`
- GitHub automation blockers: none currently. `gh` is unavailable, but authenticated git/Git Credential Manager/API paths have worked for this repository.
- Commit planned for this pass: `Add DepotDownloader backend diagnostics`

## Current Status

Initial MVP scaffold is complete and locally validated as far as possible. SteamCMD remains the default download backend and is still blocked by anonymous-login failure from Docker Desktop on this host.

DepotDownloader was added as an explicit diagnostic/fallback backend. It successfully downloaded AppID `443030` from this environment and verified native Linux server files. Full MVP success is still not claimed because SteamCMD default download behavior and Workshop mod behavior remain unverified end to end.

## Environment Clarification

- The Codex host has public internet access.
- The Codex host has no LAN access by design.
- LAN, Rocky Linux, and Unraid connectivity tests are not valid from this environment.
- Docker Desktop diagnostics from this host should focus on public internet, container networking/DNS, firewall/security filtering, proxy/VPN behavior, and SteamCMD/Steam protocol behavior inside containers.

## Work Performed This Pass

- Added `DOWNLOAD_BACKEND=steamcmd` default.
- Added supported server download backends:
  - `steamcmd`: SteamCMD only.
  - `depotdownloader`: DepotDownloader only.
  - `auto`: SteamCMD first, then logged DepotDownloader fallback if SteamCMD fails.
- Added build-time DepotDownloader installer:
  - Script: `scripts/install-depotdownloader.sh`
  - Version: `DepotDownloader_3.4.0`
  - Source: `https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_3.4.0/DepotDownloader-linux-x64.zip`
  - Image path: `/opt/depotdownloader/DepotDownloader`
- Updated `scripts/update-server.sh` to log selected backend, AppID, install path, validation mode, exit code, and backend log path.
- Updated `scripts/start-server.sh` to prefer the verified downloaded launcher `ConanSandboxServer.sh`.
- Added DepotDownloader diagnostics:
  - `tests/depotdownloader-connectivity.ps1`
  - `tests/depotdownloader-connectivity.sh`
- Updated SteamCMD and DepotDownloader diagnostics to include the process ID in default log folder names, preventing same-second PowerShell/Bash log collisions.
- Kept Workshop mod downloads on SteamCMD. `MOD_DOWNLOAD_BACKEND` was not implemented because `.pak` layout, ordered modlist behavior, and server-side mod loading are not fully verified.
- Updated project docs and README with current backend behavior, verified file paths, and remaining blockers.

## Verified DepotDownloader Results

Diagnostic log root:

```text
test-results/depotdownloader-connectivity/20260623T203026Z/
```

PowerShell DepotDownloader diagnostic summary:

- `host-dns`: pass
- `host-release-https`: pass
- `docker-version`: pass
- `container-release-https`: pass
- `project-image-present`: pass
- `depotdownloader-version`: pass
- `depotdownloader-app-manifest-only`: pass
- `depotdownloader-project-app-update`: pass
- `InconclusiveCount=0`
- `DepotDownloaderFailureCount=0`
- `FailureCount=0`

Verified binary output:

```text
DepotDownloader v3.4.0+c553ef4d60c00a4f5fd16c9fe017f569001589ff
```

AppID `443030` download result:

- Download backend: `depotdownloader`
- Downloaded bytes: `3997931312`
- Uncompressed bytes: `4727137130`
- Linux depot observed in logs: `443032`
- Backend log: `test-results/depotdownloader-connectivity/20260623T203026Z/logs/depotdownloader/update-server-443030-20260623T203145Z.log`

Verified downloaded server layout:

- Root launcher: `ConanSandboxServer.sh`
- Native Linux executable: `ConanSandbox/Binaries/Linux/ConanSandboxServer-Linux-Shipping`
- BattlEye files found under: `ConanSandbox/Binaries/Linux/BattlEye/`
- Initial downloaded config before first launch: `Engine/Config/StagedBuild_ConanSandbox.ini`
- Generated persistent config path after `configure-server.sh`: `ConanSandbox/Saved/Config/LinuxServer/`
- Generated config files: `ServerSettings.ini`, `Engine.ini`, `Game.ini`
- Generated server log path: `ConanSandbox/Saved/Logs/ConanSandbox.log`

Bounded launch/config probe:

- Launch path used: `ConanSandboxServer.sh`
- Config profile: `LinuxServer`
- Loaded config: `../../../ConanSandbox/Saved/Config/LinuxServer/ServerSettings.ini`
- Reached `Game Engine Initialized`
- Opened socket on `0.0.0.0:7777`
- Reached `StartPlay`
- Expected public-registration issue observed: `Autologin attempt failed, unable to register server!`
- This verifies local launch/config path behavior only; it does not prove public server registration or full gameplay readiness.

Workshop fallback investigation:

- Public Conan Workshop item checked: `880454836` (`[Legacy] Pippi - User & Server Management`)
- First DepotDownloader `-pubfile` command without `-app` failed with `Error: -app not specified!`
- Second command with `-app 440900 -pubfile 880454836 -manifest-only` reached Steam anonymously and completed manifest-only behavior.
- This did not prove `.pak` download layout, ordered modlist generation, pruning, or server-side mod loading, so mod backend behavior was not changed.

## SteamCMD Blocker

SteamCMD anonymous login still fails from Docker Desktop on this host:

```text
Connecting anonymously to Steam Public...
FAILED (No Connection)
```

The same failure has occurred in:

- This project image.
- Upstream `steamcmd/steamcmd:ubuntu-24`.
- Upstream SteamCMD with DNS override checks.
- Upstream SteamCMD with Docker host networking.

Current evidence shows host public DNS/HTTPS and generic container DNS/HTTPS/package access work. The remaining blocker is SteamCMD/Steam protocol behavior from containers or a temporary Steam-side issue, not general Docker internet, AppID availability, or native Linux file layout.

## Latest Validation Results

Completed before this handoff update:

- `docker compose config`: passed
- Bash syntax checks for scripts/tests in an Ubuntu container: passed
- PowerShell parser checks for diagnostics: passed
- `docker compose build`: passed
- PowerShell DepotDownloader diagnostics: passed with `FailureCount=0`
- AppID `443030` file-layout verification: passed through DepotDownloader diagnostic download
- Bounded launch/config probe: reached server start path and `StartPlay`
- Workshop DepotDownloader pubfile manifest-only probe: partial diagnostic pass; not enough to implement mod backend

Final validation after doc edits:

- `docker compose config`: passed
- Bash syntax checks for all shell scripts and Bash diagnostics in `ubuntu:24.04`: passed
- PowerShell parser checks for `tests/steamcmd-connectivity.ps1` and `tests/depotdownloader-connectivity.ps1`: passed
- `git diff --check`: passed; only Git line-ending warnings were reported
- `docker compose build`: passed
- PowerShell SteamCMD diagnostics with `-SkipDnsOverride -SkipAppUpdateAttempt -SkipHostNetwork`: passed as a diagnostic run with `FailureCount=0`, `InconclusiveCount=5`, `SteamFailureCount=4`
- Bash SteamCMD diagnostics with `--skip-dns-override --skip-app-update-attempt --skip-host-network`: passed as a diagnostic run with `FailureCount=0`, `InconclusiveCount=5`, `SteamFailureCount=4`
- PowerShell DepotDownloader diagnostics with `-SkipAppUpdateAttempt`: passed with `FailureCount=0`, `DepotDownloaderFailureCount=0`, `InconclusiveCount=1` for the intentionally skipped app update
- Bash DepotDownloader diagnostics with `--skip-app-update-attempt`: passed with `FailureCount=0`, `DepotDownloaderFailureCount=0`, `InconclusiveCount=1` for the intentionally skipped app update

Final diagnostic log roots:

- PowerShell SteamCMD: `test-results/steamcmd-connectivity/20260623T210513Z-17088/`
- Bash SteamCMD: `test-results/steamcmd-connectivity/20260623T210513Z-890/`
- PowerShell DepotDownloader: `test-results/depotdownloader-connectivity/20260623T210513Z-12468/`
- Bash DepotDownloader: `test-results/depotdownloader-connectivity/20260623T210513Z-891/`

Earlier same-second diagnostic runs created collisions under `20260623T205013Z`; the scripts were fixed to prevent that by appending process IDs to default log roots. The clean rerun above verified the fix.

## Cleanup Status

- Kept proof logs under `test-results/depotdownloader-connectivity/20260623T203026Z/`.
- Removed disposable bulk diagnostic data from `test-results/depotdownloader-connectivity/20260623T203026Z/`: `serverfiles/`, `steam/`, and `home/`.
- Preserved diagnostic summaries, raw logs, generated config files, server logs, manifest-only output, and Workshop probe logs.
- Ran `docker compose down --remove-orphans`; no services remained running.
- Local ignored `data/` and `test-results/` remain intentionally untracked/ignored.

## Next Recommended Steps

1. Use `DOWNLOAD_BACKEND=depotdownloader` for further local Docker Desktop server-file experiments while SteamCMD remains blocked.
2. Retest SteamCMD later with `tests/steamcmd-connectivity.ps1` or `tests/steamcmd-connectivity.sh`.
3. Run the same SteamCMD diagnostics from the Rocky Linux Docker host itself as a clean comparison. Do not test Rocky/Unraid/LAN access from this Codex host.
4. Verify Workshop mod downloads with real `.pak` files and confirm whether `ConanSandbox/Mods/modlist.txt` should contain absolute paths or another format.
5. Run a full compose first boot with an explicit backend once the user chooses whether local testing should use DepotDownloader or keep waiting for SteamCMD recovery.
6. Do not claim MVP success until server update, config, launch, restart persistence, backups, Workshop mods, modlist behavior, graceful shutdown, and non-secret logging are all verified end to end.

## Important Decisions

- Use native Linux dedicated server files.
- Do not switch to Wine.
- Keep SteamCMD as the default backend.
- Keep DepotDownloader explicit and logged.
- Do not silently fallback.
- Do not print tokens, passwords, or secrets.
- Keep GitHub repository work automation-first and private by default.
