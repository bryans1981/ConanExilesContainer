# Session Handoff

## Current Git/GitHub State

- Current branch: `main`
- Remote name: `origin`
- Remote URL: `https://github.com/bryans1981/ConanExilesContainer.git`
- GitHub visibility: private
- Latest pushed commit before this pass: `877ebcc Add DepotDownloader backend diagnostics`
- Previous pushed commit: `af3b08c Add SteamCMD diagnostics and local host network clarification`
- Initial scaffold commit: `9ae5a6f Initial Conan Exiles container scaffold`
- GitHub automation blockers: none currently. `gh` is unavailable, but authenticated git/Git Credential Manager/API paths have worked for this repository.
- Commit planned for this pass: `Diagnose Docker SteamCMD security profile issue`

## Current Status

Initial MVP scaffold is complete and locally validated as far as possible. DepotDownloader remains the recommended normal backend for this Docker Desktop host because Docker Engine `29.4.2` blocks Linux SteamCMD under the default builtin seccomp profile.

SteamCMD is not broken on the Windows host. Windows SteamCMD works from `C:\Conan Exiles Server\DedicatedServerLauncher\steamcmd.exe`. Linux SteamCMD works in Docker when run with diagnostic `seccomp=unconfined`. This proves the local failure is Docker security-profile specific, not a general Steam outage or host internet issue.

Full MVP success is still not claimed. Server files, launch path, and config behavior are verified through DepotDownloader and a bounded launch probe, and single-mod download/modlist generation are verified under diagnostic `seccomp=unconfined`; live server mod loading, multi-mod behavior, pruning, backups with mods, and full first boot remain unverified.

## Environment Clarification

- The Codex host has public internet access.
- The Codex host has no LAN access by design.
- LAN, Rocky Linux, and Unraid connectivity tests are not valid from this environment.
- Docker Desktop diagnostics from this host should focus on public internet, container networking/DNS, firewall/security filtering, proxy/VPN behavior, and SteamCMD/Steam protocol behavior inside containers.

## Docker/Seccomp Findings

Captured Docker environment:

- Docker Desktop: `4.72.0 (225998)`
- Docker Engine: `29.4.2`
- containerd: `v2.2.3`
- runc: `1.3.5`
- Docker context: `desktop-linux`
- Kernel: `6.6.87.2-microsoft-standard-WSL2`
- Security options: `seccomp`, profile `builtin`

Evidence:

- Windows host SteamCMD version/login/app-info: pass.
- Upstream `steamcmd/steamcmd:ubuntu-24` with default builtin seccomp: fail/inconclusive with `CreateBoundSocket: failed to create socket, error [no name available] (38)` and `FAILED (No Connection)`.
- Upstream `steamcmd/steamcmd:ubuntu-24` with `--security-opt seccomp=unconfined`: pass for anonymous login and AppID `443030` app-info.
- Project image with default builtin seccomp: fail/inconclusive.
- Project image with `--security-opt seccomp=unconfined`: pass for anonymous login.
- Compose override with `security_opt: seccomp=unconfined`: config renders and AppID `443030` app-info passes.

Docker Engine 29 release notes document that `29.4.2` blocks `AF_ALG` sockets and `socketcall(2)` in the default seccomp profile and lists SteamCMD as affected. Docker `29.4.3` release notes document replacing the broad `socketcall` deny with targeted LSM controls.

References:

- `https://docs.docker.com/engine/release-notes/29/#2942`
- `https://docs.docker.com/engine/release-notes/29/#2943`

Recommended action:

1. Upgrade Docker Engine/Desktop to a release containing the `29.4.3` seccomp compatibility fix when available.
2. Use `DOWNLOAD_BACKEND=depotdownloader` for normal local server-file testing on Docker Engine `29.4.2`.
3. Use `docker-compose.steamcmd-unconfined.diagnostic.yml` only as a diagnostic/emergency workaround because it disables Docker seccomp filtering for the Conan service.

## Work Performed This Pass

- Added `tests/windows-steamcmd-comparison.ps1`.
- Added `tests/steamcmd-security-diagnostics.ps1`.
- Added `tests/steamcmd-security-diagnostics.sh`.
- Added `docker-compose.steamcmd-unconfined.diagnostic.yml`.
- Updated `scripts/update-mods.sh` to capture SteamCMD Workshop output in timestamped logs under `/serverdata/logs/steamcmd/`.
- Updated `AGENTS.md`, `PROJECT.md`, `PROJECT_MAP.md`, `README.md`, `docs/CONFIG.md`, `docs/LOCAL_DOCKER_DESKTOP.md`, `docs/MODS.md`, `docs/TROUBLESHOOTING_STEAMCMD.md`, and this handoff.

## Diagnostic Results This Pass

Windows host SteamCMD comparison:

- Log root: `test-results/windows-steamcmd-comparison/20260623T215056Z-9520/`
- SteamCMD path: `C:\Conan Exiles Server\DedicatedServerLauncher\steamcmd.exe`
- `windows-steamcmd-version`: pass
- `windows-steamcmd-login`: pass
- `windows-steamcmd-app-info`: pass
- Optional app-update probe: skipped by default
- `FailureCount=0`

SteamCMD Docker security diagnostics:

- PowerShell log root: `test-results/steamcmd-security-diagnostics/20260623T215056Z-14712/`
- Bash log root: `test-results/steamcmd-security-diagnostics/20260623T215056Z-1235/`
- Docker info/version/context capture: pass
- Docker Desktop CLI plugin version capture: pass
- Upstream default login: inconclusive/fail
- Upstream `seccomp=unconfined` login: pass
- Upstream default app-info: inconclusive/fail
- Upstream `seccomp=unconfined` app-info: pass
- Project default login: inconclusive/fail
- Project `seccomp=unconfined` login: pass
- Host-network check: skipped in the final run
- Custom seccomp profile: not added because no narrow profile was verified. A scratch test using Docker's `seccomp/v0.2.1` profile downloaded/started SteamCMD but remained inconclusive after repeated Steam login retries, so it was not committed as `docker/seccomp/steamcmd-diagnostic.json`.

Workshop mod diagnostics:

- Test item: `3720546346` (`[Enhanced] Unlimited Weight`)
- Steam API reported size: `312179` bytes
- PowerShell SteamCMD/unconfined proof log root: `test-results/workshop-mod-diagnostics/20260623T222112Z-3376-project-steamcmd-logged/`
- SteamCMD with diagnostic `seccomp=unconfined`: pass
- Timestamped SteamCMD mod log was written under the diagnostic `/diagnostics/logs/steamcmd/` path.
- Verified `.pak`: `steamapps/workshop/content/440900/3720546346/HEUnlimitedWeight.pak`
- Generated modlist: `ConanSandbox/Mods/modlist.txt`
- Generated modlist line: `/diagnostics/steam/steamapps/workshop/content/440900/3720546346/HEUnlimitedWeight.pak`
- Active mod file: `ConanSandbox/Mods/.active-workshop-mods`

DepotDownloader Workshop pubfile status:

- Direct full `DepotDownloader -app 440900 -pubfile 3720546346` succeeded once and produced `HEUnlimitedWeight.pak`.
- Immediate integrated/retry attempts failed to connect to Steam after 10 tries.
- `MOD_DOWNLOAD_BACKEND` was not implemented because the DepotDownloader Workshop path was not stable enough to promote.

Previously verified DepotDownloader server results:

- `DOWNLOAD_BACKEND=depotdownloader` downloaded AppID `443030`.
- Verified launcher: `ConanSandboxServer.sh`
- Verified executable: `ConanSandbox/Binaries/Linux/ConanSandboxServer-Linux-Shipping`
- Bounded launch/config probe reached `StartPlay`.

## Final Validation This Pass

- `git status`, branch, remote, and log checked at start; worktree was clean against `origin/main`.
- `docker compose config`: passed.
- `docker compose -f docker-compose.yml -f docker-compose.steamcmd-unconfined.diagnostic.yml config`: passed.
- Bash syntax checks for scripts and diagnostics in `ubuntu:24.04`: passed.
- PowerShell parser checks for all PowerShell diagnostics: passed.
- `git diff --check`: passed; only expected CRLF warnings were reported.
- `docker compose build`: passed after final script changes.
- `tests/windows-steamcmd-comparison.ps1`: passed as above.
- `tests/steamcmd-security-diagnostics.ps1 -SkipHostNetwork`: passed as a diagnostic run with expected SteamCMD failures under default seccomp and passes under unconfined.
- `tests/steamcmd-security-diagnostics.sh --skip-host-network`: passed as a diagnostic run with matching results.
- Existing PowerShell SteamCMD connectivity diagnostics were rerun with `-SkipDnsOverride -SkipAppUpdateAttempt -SkipHostNetwork`.
  - Log root: `test-results/steamcmd-connectivity/20260623T222549Z-14408/`
  - Host DNS/HTTPS, Docker, container DNS/HTTPS, and package repository checks: pass
  - Project image SteamCMD login/app-info: inconclusive/fail under default seccomp
  - Upstream SteamCMD login/app-info: inconclusive/fail under default seccomp
  - `FailureCount=0`, `InconclusiveCount=5`, `SteamFailureCount=4`
- PowerShell DepotDownloader diagnostics were rerun with `-SkipAppUpdateAttempt`.
  - Log root: `test-results/depotdownloader-connectivity/20260623T223751Z-4888/`
  - Host DNS/release HTTPS, Docker, container release HTTPS, project image, DepotDownloader version, and AppID `443030` manifest-only checks: pass
  - Full project app update was skipped to avoid another 4 GB download
  - `FailureCount=0`, `DepotDownloaderFailureCount=0`, `InconclusiveCount=1`
  - Prior successful full server download remains under `test-results/depotdownloader-connectivity/20260623T203026Z/`.

## Cleanup Status

- Removed disposable bulk SteamCMD cache/home data from Workshop diagnostic roots after preserving proof logs, generated modlist files, and the small downloaded `.pak`.
- Removed previous disposable DepotDownloader server bulk data in the prior pass; proof logs remain.
- Ran `docker compose down --remove-orphans`; compose network was removed and no compose services remain running.
- Local ignored `data/` and `test-results/` remain intentionally untracked/ignored.
- The compose override diagnostic touched ignored local `data/steam` during AppID app-info testing; it was retained rather than deleted to avoid removing possible user/runtime data.

## Next Recommended Steps

1. Upgrade Docker Engine/Desktop to a release with the `29.4.3` seccomp compatibility fix, then rerun `tests/steamcmd-security-diagnostics.ps1`.
2. Until Docker is upgraded, use `DOWNLOAD_BACKEND=depotdownloader` for normal local server-file testing.
3. Use `docker-compose.steamcmd-unconfined.diagnostic.yml` only when intentionally testing SteamCMD or Workshop mods on Docker Engine `29.4.2`.
4. Run a full compose first boot with `DOWNLOAD_BACKEND=depotdownloader`.
5. Verify live server mod loading using the downloaded `HEUnlimitedWeight.pak` or another small public mod.
6. Verify multi-mod ordering, pruning, backup behavior with mods, graceful shutdown, and restart persistence before claiming MVP success.
7. Run Rocky Linux testing from the Rocky Linux host itself, not from this Codex host.

## Important Decisions

- Use native Linux dedicated server files.
- Do not switch to Wine.
- Keep SteamCMD as the default variable value, but recommend DepotDownloader for Docker Engine `29.4.2` local testing.
- Keep `seccomp=unconfined` diagnostic/emergency-only.
- Do not commit a custom seccomp profile until a narrow profile is verified locally.
- Do not implement `MOD_DOWNLOAD_BACKEND` until the DepotDownloader Workshop path is stable.
- Do not print tokens, passwords, or secrets.
- Keep GitHub repository work automation-first and private by default.
