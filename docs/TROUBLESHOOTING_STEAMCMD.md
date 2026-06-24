# SteamCMD Troubleshooting

## Current Blocker

Docker Desktop on the current local host can start SteamCMD, but Linux SteamCMD anonymous login fails under Docker's default builtin seccomp profile before Conan Exiles Dedicated Server AppID `443030` can be downloaded through SteamCMD.

Observed SteamCMD failure:

```text
CreateBoundSocket: failed to create socket, error [no name available] (38)
Connecting anonymously to Steam Public...
FAILED (No Connection)
```

## Evidence

- The Codex host has public internet access.
- The Codex host does not have LAN access by design.
- Windows host SteamCMD works from `C:\Conan Exiles Server\DedicatedServerLauncher\steamcmd.exe`.
- The project image can start SteamCMD with the seeded non-root Steam home.
- The same anonymous-login failure occurs in the upstream `steamcmd/steamcmd:ubuntu-24` image under Docker's default security profile.
- The same project and upstream Linux SteamCMD login/app-info checks pass with diagnostic `--security-opt seccomp=unconfined`.
- HTTPS access from containers has worked for Docker image/package downloads, so this is not currently proven to be general Docker internet failure.
- Docker Engine is `29.4.2`; Docker security options show `seccomp` with `Profile: builtin`.

## Meaning

Current evidence points to a Docker Engine/Desktop `29.4.2` seccomp compatibility problem with Linux SteamCMD in containers. It is not evidence that Steam is down, that Windows host networking is broken, or that the project app logic is wrong.

Do not treat lack of LAN access as a SteamCMD blocker. This Codex host is intentionally public-internet-only.

The normal compose path now uses DepotDownloader for server and Workshop downloads by default, so it does not require `seccomp=unconfined`. Do not claim SteamCMD itself is fixed unless it passes again under Docker's default security profile.

## Docker Seccomp Findings

Captured local Docker environment:

- Docker Desktop: `4.72.0 (225998)`
- Docker Engine: `29.4.2`
- containerd: `v2.2.3`
- runc: `1.3.5`
- Docker context: `desktop-linux`
- Kernel: `6.6.87.2-microsoft-standard-WSL2`
- Security options: `seccomp`, profile `builtin`

Diagnostics on June 23, 2026:

- Windows host SteamCMD version/login/app-info: pass.
- Upstream Linux SteamCMD with default Docker seccomp: fail/inconclusive with `CreateBoundSocket` and `FAILED (No Connection)`.
- Upstream Linux SteamCMD with `seccomp=unconfined`: pass.
- Project image Linux SteamCMD with default Docker seccomp: fail/inconclusive.
- Project image Linux SteamCMD with `seccomp=unconfined`: pass.
- Compose override with `security_opt: seccomp=unconfined`: config renders and app-info passes.

Docker's Engine 29 release notes document a `29.4.2` seccomp hardening change that blocks `AF_ALG` sockets and `socketcall(2)`, and explicitly lists SteamCMD and Wine as impacted workloads. Docker's `29.4.3` notes document replacing the broad `socketcall` deny with targeted LSM controls.

References:

- https://docs.docker.com/engine/release-notes/29/#2942
- https://docs.docker.com/engine/release-notes/29/#2943

Preferred remediation:

1. Upgrade Docker Engine/Desktop to a version containing the `29.4.3` seccomp compatibility fix when available for Docker Desktop.
2. Keep the default DepotDownloader backend for normal local testing until Docker is upgraded.
3. Use `docker-compose.steamcmd-unconfined.diagnostic.yml` only as a diagnostic/emergency workaround.

Diagnostic/emergency override:

```powershell
docker compose -f docker-compose.yml -f docker-compose.steamcmd-unconfined.diagnostic.yml up
```

This override is less secure than Docker's default isolation because it disables seccomp filtering for the Conan service. Do not make it the default.

## DepotDownloader Default Path

DepotDownloader is the default server and Workshop mod download backend for this project because it has been verified under Docker default security on this host. SteamCMD remains available as an explicit backend for hosts where Linux SteamCMD works.

Current backend values:

- `DOWNLOAD_BACKEND=steamcmd`: use SteamCMD only.
- `DOWNLOAD_BACKEND=depotdownloader`: use DepotDownloader only.
- `DOWNLOAD_BACKEND=auto`: try DepotDownloader first, log its failure path, then try SteamCMD.
- `MOD_DOWNLOAD_BACKEND=steamcmd`: use SteamCMD only for Workshop mods.
- `MOD_DOWNLOAD_BACKEND=depotdownloader`: use DepotDownloader only for Workshop mods.
- `MOD_DOWNLOAD_BACKEND=auto`: try DepotDownloader first, log its failure path, then try SteamCMD.

Verified on June 23, 2026:

- DepotDownloader source: official SteamRE GitHub release `DepotDownloader_3.4.0`.
- Image binary output: `DepotDownloader v3.4.0+c553ef4d60c00a4f5fd16c9fe017f569001589ff`.
- Anonymous AppID `443030` manifest-only check passed.
- `DOWNLOAD_BACKEND=depotdownloader` downloaded AppID `443030` Linux files.
- Verified launcher: `ConanSandboxServer.sh`.
- Verified executable: `ConanSandbox/Binaries/Linux/ConanSandboxServer-Linux-Shipping`.
- Generated config path during launch probe: `ConanSandbox/Saved/Config/LinuxServer/`.
- Server log path during launch probe: `ConanSandbox/Saved/Logs/ConanSandbox.log`.
- The bounded launch probe reached `Game Engine Initialized`, loaded `ServerSettings.ini`, listened on port `7777`, and entered `StartPlay`.
- DepotDownloader Workshop `-pubfile` download for item `3720546346` produced `HEUnlimitedWeight.pak`.
- Integrated `MOD_DOWNLOAD_BACKEND=depotdownloader` generated `ConanSandbox/Mods/modlist.txt` in the requested order.
- Clean disposable compose e2e using the DepotDownloader defaults downloaded server files, generated config, downloaded the Workshop mod, reached `StartPlay`, stopped gracefully, restarted, preserved config/modlist, and created backups.

This proves the default DepotDownloader path works from this environment for the tested server and single-mod flow. It does not prove that SteamCMD is fixed.

## Repeatable Diagnostics

From the repo root on Windows:

```powershell
docker compose build
.\tests\steamcmd-connectivity.ps1
.\tests\windows-steamcmd-comparison.ps1
.\tests\steamcmd-security-diagnostics.ps1
```

From a Bash-compatible shell:

```bash
docker compose build
./tests/steamcmd-connectivity.sh
./tests/steamcmd-security-diagnostics.sh
```

DepotDownloader comparison diagnostics:

```powershell
.\tests\depotdownloader-connectivity.ps1
```

```bash
./tests/depotdownloader-connectivity.sh
```

Diagnostics write raw logs and a summary under ignored `test-results/` subdirectories. These files are disposable and can be removed after important results are captured in `SESSION_HANDOFF.md` or issue notes.

```text
./test-results/steamcmd-connectivity/
./test-results/windows-steamcmd-comparison/
./test-results/steamcmd-security-diagnostics/
./test-results/depotdownloader-connectivity/
```

By default, SteamCMD login/update failures are reported as inconclusive checks but do not make the script exit nonzero. To use the diagnostics in a stricter CI-like mode, enable SteamCMD failure mode:

```powershell
.\tests\steamcmd-connectivity.ps1 -StrictSteamFailures
```

```bash
./tests/steamcmd-connectivity.sh --strict-steam-failures
```

## Checks To Perform

- Confirm Docker Desktop general internet access.
- Confirm Codex host public internet access.
- Confirm Docker Desktop DNS resolution from containers.
- Confirm HTTPS access from containers.
- Confirm package repository reachability from containers.
- Check Windows firewall and endpoint/security software.
- Check Docker Desktop backend network rules.
- Check VPN or proxy interference.
- Check SteamCMD-specific protocol/login behavior.
- Check Docker Engine/Desktop version.
- Check `docker info` security options and seccomp profile.
- Compare Docker default seccomp against diagnostic `seccomp=unconfined`.
- Compare with explicit `DOWNLOAD_BACKEND=steamcmd` only when diagnosing SteamCMD-specific failures because DepotDownloader is already the default path.
- Try public DNS override checks with Docker `--dns 1.1.1.1` and `--dns 8.8.8.8`.
- Try Docker Desktop host networking if it is available/enabled.
- Retest on the Rocky Linux Docker host as a clean comparison later. Do not attempt Rocky Linux, Unraid, or LAN connectivity tests from the local Codex host.

## Things Not To Do

- Do not switch to Wine as a workaround for this connectivity blocker.
- Do not mark download, launch, update, mod, or MVP behavior as working without real AppID `443030` files.
- Do not leave `seccomp=unconfined` enabled as a default production setting.
- Do not change the default backend again without verified reason and explicit user approval.
- Do not claim broad Workshop coverage until multi-mod ordering, removal, and pruning are verified with real mods.
- Do not print tokens, passwords, or secrets in diagnostic output.
