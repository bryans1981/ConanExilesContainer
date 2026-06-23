# Session Handoff

## Current Git/GitHub State

- Current branch: `main`
- Remote name: `origin`
- Remote URL: `https://github.com/bryans1981/ConanExilesContainer.git`
- GitHub visibility: private
- Latest pushed commit at start of this pass: `a1b9a5d Diagnose Docker SteamCMD security profile issue`
- Previous pushed commit: `877ebcc Add DepotDownloader backend diagnostics`
- Initial scaffold commit: `9ae5a6f Initial Conan Exiles container scaffold`
- Commit planned for this pass: `Finalize safe downloader backend defaults`
- GitHub automation blockers: none currently. `gh` is unavailable, but authenticated git/Git Credential Manager/API paths have worked for this repository.

## Current Status

The local Docker Desktop default-flow MVP smoke test passed on June 23, 2026.

Normal compose defaults are now:

- `DOWNLOAD_BACKEND=depotdownloader`
- `MOD_DOWNLOAD_BACKEND=depotdownloader`

The clean disposable e2e run used those defaults and proved:

- AppID `443030` server download through DepotDownloader.
- Native launcher `ConanSandboxServer.sh`.
- Native executable `ConanSandbox/Binaries/Linux/ConanSandboxServer-Linux-Shipping`.
- Config generation under `ConanSandbox/Saved/Config/LinuxServer/`.
- Server name, test server/admin/RCON passwords, max players, and ports applied.
- Test password values did not appear in retained Docker/server logs.
- Workshop item `3720546346` downloaded through DepotDownloader.
- Verified `.pak`: `HEUnlimitedWeight.pak`.
- `ConanSandbox/Mods/modlist.txt` generated with the expected absolute `.pak` path.
- Active mod order state written to `ConanSandbox/Mods/.active-workshop-mods`.
- Server reached `StartPlay`.
- Graceful shutdown marker observed.
- Restart reached `StartPlay` and did not wipe config/modlist.
- Backup archives were created.

Remaining work is no longer a blocker for the local single-mod MVP smoke flow, but should still be tested later:

- Multi-mod ordering with more than one real mod.
- Removing mod IDs and pruning old downloads.
- Longer-running public server behavior.
- Rocky Linux and Unraid deployment from those hosts.

## SteamCMD Blocker Status

SteamCMD is still blocked under Docker Desktop default security on this host.

Known facts:

- Windows host SteamCMD works from `C:\Conan Exiles Server\DedicatedServerLauncher\steamcmd.exe`.
- Linux SteamCMD fails under Docker Engine `29.4.2` builtin seccomp in both the project image and upstream `steamcmd/steamcmd:ubuntu-24`.
- Failure signature includes `CreateBoundSocket: failed to create socket, error [no name available] (38)` and `FAILED (No Connection)`.
- Linux SteamCMD passes when run with diagnostic `seccomp=unconfined`.
- This remains a Docker Engine/Desktop `29.4.2` seccomp compatibility issue, not a general host internet, Docker DNS, AppID, or project app-logic failure.
- `docker-compose.steamcmd-unconfined.diagnostic.yml` remains diagnostic/emergency-only and is not part of the normal compose path.

Captured Docker environment:

- Docker Desktop: `4.72.0 (225998)`
- Docker Engine: `29.4.2`
- containerd: `v2.2.3`
- runc: `1.3.5`
- Docker context: `desktop-linux`
- Kernel: `6.6.87.2-microsoft-standard-WSL2`
- Security options: `seccomp`, profile `builtin`

## Work Performed This Pass

- Verified direct DepotDownloader Workshop `-pubfile` download for item `3720546346` under Docker default security.
- Implemented `MOD_DOWNLOAD_BACKEND=steamcmd|depotdownloader|auto`.
- Changed default server backend to `depotdownloader`.
- Changed default Workshop mod backend to `depotdownloader`.
- Changed server and mod `auto` modes to try DepotDownloader first, then SteamCMD with explicit logging.
- Kept SteamCMD as an explicit backend for hosts where it works.
- Kept `docker-compose.steamcmd-unconfined.diagnostic.yml` diagnostic/emergency-only.
- Fixed SteamCMD connectivity diagnostics so their project app-update path explicitly sets `DOWNLOAD_BACKEND=steamcmd`.
- Ran clean disposable compose e2e with the DepotDownloader defaults.
- Updated `AGENTS.md`, `PROJECT.md`, `PROJECT_MAP.md`, `README.md`, `.env.example`, `docs/CONFIG.md`, `docs/MODS.md`, `docs/TROUBLESHOOTING_STEAMCMD.md`, `docs/LOCAL_DOCKER_DESKTOP.md`, and this handoff.

## Diagnostic Results This Pass

DepotDownloader diagnostics:

- Command: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\depotdownloader-connectivity.ps1 -SkipAppUpdateAttempt`
- Log root: `test-results/depotdownloader-connectivity/20260623T231504Z-14148/`
- Host DNS/release HTTPS: pass.
- Docker version: pass.
- Container release HTTPS: pass.
- Project image present: pass.
- Image DepotDownloader version: pass.
- AppID `443030` manifest-only access: pass.
- Project app update: skipped to avoid a redundant multi-GB download; full e2e covered the default app download.
- `FailureCount=0`, `DepotDownloaderFailureCount=0`, `InconclusiveCount=1`.

SteamCMD connectivity diagnostics:

- Command: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\steamcmd-connectivity.ps1 -SkipDnsOverride -SkipAppUpdateAttempt -SkipHostNetwork`
- Log root: `test-results/steamcmd-connectivity/20260623T231504Z-15108/`
- Host DNS/HTTPS: pass.
- Docker version: pass.
- Container DNS/HTTPS/package repository: pass.
- Project image present: pass.
- Project SteamCMD login/app-info: inconclusive/fail under default seccomp.
- Upstream SteamCMD login/app-info: inconclusive/fail under default seccomp.
- Project app update: skipped to avoid writing to normal compose data during a known failing SteamCMD path.
- `FailureCount=0`, `SteamFailureCount=4`, `InconclusiveCount=5`.

SteamCMD security diagnostics:

- Command: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\steamcmd-security-diagnostics.ps1 -SkipHostNetwork`
- Log root: `test-results/steamcmd-security-diagnostics/20260623T231504Z-6368/`
- Docker version/info/context/Desktop version: pass.
- Upstream default login/app-info: inconclusive/fail.
- Upstream `seccomp=unconfined` login/app-info: pass.
- Project default login: inconclusive/fail.
- Project `seccomp=unconfined` login: pass.
- Custom seccomp profile: skipped because no verified narrow profile exists.
- Host network: skipped by flag.
- `FailureCount=0`, `SteamFailureCount=3`, `InconclusiveCount=5`.

Workshop mod backend diagnostics:

- Direct DepotDownloader proof root: `test-results/workshop-mod-diagnostics/20260623T230717Z-2348-depotdownloader-default/`
- Integrated project proof root: `test-results/workshop-mod-diagnostics/20260623T231351Z-project-depotdownloader-default/`
- Prune-disabled proof root: `test-results/workshop-mod-diagnostics/20260623T234858Z-project-depotdownloader-prune-disabled/`
- Test item: `3720546346` (`[Enhanced] Unlimited Weight`)
- Backend: `MOD_DOWNLOAD_BACKEND=depotdownloader`
- Docker security: default, no `seccomp=unconfined`
- Verified `.pak`: `HEUnlimitedWeight.pak`
- Generated modlist: `ConanSandbox/Mods/modlist.txt`
- Active mod state: `ConanSandbox/Mods/.active-workshop-mods`
- `PRUNE_REMOVED_MODS=false` still refreshes active mod state while leaving old downloads on disk.
- Result: pass.

Clean e2e proof:

- Proof root: `test-results/e2e/20260623T233043Z-depotdownloader-default/proof/`
- Temporary project: `conane2e20260623233043`
- Commands:
  - `docker compose -p conane2e20260623233043 -f docker-compose.yml -f test-results/e2e/20260623T233043Z-depotdownloader-default/compose.e2e.yml config --quiet`
  - `docker compose -p conane2e20260623233043 -f docker-compose.yml -f test-results/e2e/20260623T233043Z-depotdownloader-default/compose.e2e.yml up -d --force-recreate --remove-orphans conan`
  - `docker compose -p conane2e20260623233043 -f docker-compose.yml -f test-results/e2e/20260623T233043Z-depotdownloader-default/compose.e2e.yml stop -t 90 conan`
  - `docker compose -p conane2e20260623233043 -f docker-compose.yml -f test-results/e2e/20260623T233043Z-depotdownloader-default/compose.e2e.yml up -d conan`
  - `docker compose -p conane2e20260623233043 -f docker-compose.yml -f test-results/e2e/20260623T233043Z-depotdownloader-default/compose.e2e.yml down --remove-orphans`
- First boot reached `StartPlay`: pass.
- Restart reached `StartPlay`: pass.
- Graceful shutdown marker: pass.
- Config/modlist persistence: pass.
- Backup archive creation: pass.
- Password value retained-log scan: pass.
- Large disposable `serverfiles` and `steam` folders were removed after proof capture.

## Validation Commands This Pass

- `git status --short --branch`
- `git branch --show-current`
- `git remote -v`
- `git log --oneline -5`
- `docker compose config --quiet`
- `docker compose -f docker-compose.yml config --quiet`
- `docker compose -f docker-compose.yml -f docker-compose.steamcmd-unconfined.diagnostic.yml config --quiet`
- `docker run --rm -v "${PWD}:/work" -w /work ubuntu:24.04 bash -n scripts/common.sh scripts/update-server.sh scripts/update-mods.sh scripts/entrypoint.sh scripts/configure-server.sh scripts/backup.sh scripts/start-server.sh scripts/healthcheck.sh tests/steamcmd-security-diagnostics.sh tests/steamcmd-connectivity.sh tests/depotdownloader-connectivity.sh`
- PowerShell parser check for all `tests/*.ps1`.
- `git diff --check`
- `docker compose build`
- DepotDownloader diagnostics, SteamCMD connectivity diagnostics, SteamCMD security diagnostics, integrated Workshop backend tests, and clean e2e compose run listed above.

## Cleanup Status

- Removed failed harness-only scratch root: `test-results/workshop-mod-diagnostics/20260623T231328Z-project-depotdownloader-default/`.
- Removed failed harness-only scratch root: `test-results/e2e/20260623T232907Z-depotdownloader-default/`.
- Removed large disposable e2e `serverfiles` and `steam` folders from `test-results/e2e/20260623T233043Z-depotdownloader-default/` after preserving proof logs.
- Kept proof roots and diagnostic logs under ignored `test-results/`.
- No e2e compose containers remain after `docker compose down --remove-orphans`.
- Ignored local `data/` was not deleted because it may contain user/runtime data.

## Next Recommended Steps

1. Commit and push this pass as `Finalize safe downloader backend defaults`.
2. Test multi-mod ordering with two or more real Conan Workshop mods.
3. Test removing a mod ID and `PRUNE_REMOVED_MODS=true` behavior.
4. Upgrade Docker Engine/Desktop to a release containing the `29.4.3` seccomp compatibility fix when available, then rerun `tests/steamcmd-security-diagnostics.ps1`.
5. Run Rocky Linux and Unraid testing from those hosts, not from this local Codex host.

## Important Decisions

- Use native Linux dedicated server files.
- Do not switch to Wine.
- DepotDownloader is the default server and Workshop download backend for this project.
- SteamCMD remains available as an explicit backend for hosts where it works.
- Keep `seccomp=unconfined` diagnostic/emergency-only.
- Do not commit a custom seccomp profile until a narrow profile is verified locally.
- Do not print tokens, passwords, or secrets.
- Keep GitHub repository work automation-first and private by default.
