# SteamCMD Troubleshooting

## Current Blocker

Docker Desktop on the current local host can start SteamCMD, but SteamCMD anonymous login fails before Conan Exiles Dedicated Server AppID `443030` can be downloaded.

Observed SteamCMD failure:

```text
Connecting anonymously to Steam Public...
FAILED (No Connection)
```

## Evidence

- The Codex host has public internet access.
- The Codex host does not have LAN access by design.
- The project image can start SteamCMD with the seeded non-root Steam home.
- The same anonymous-login failure occurs in the upstream `steamcmd/steamcmd:ubuntu-24` image.
- The same anonymous-login failure occurs when the upstream image is run with Docker host networking.
- HTTPS access from containers has worked for Docker image/package downloads, so this is not currently proven to be general Docker internet failure.

## Meaning

Current evidence points to a Docker Desktop, local network, firewall, proxy, VPN, DNS, or Steam connectivity problem. It is not yet evidence that the project app logic is wrong.

Do not treat lack of LAN access as a SteamCMD blocker. This Codex host is intentionally public-internet-only.

Do not claim a fix or MVP success until AppID `443030` downloads successfully and the real server executable, paths, config files, launch behavior, Workshop handling, and modlist behavior are verified from actual downloaded files.

## Repeatable Diagnostics

From the repo root on Windows:

```powershell
docker compose build
.\tests\steamcmd-connectivity.ps1
```

From a Bash-compatible shell:

```bash
docker compose build
./tests/steamcmd-connectivity.sh
```

Diagnostics write raw logs and a summary under:

```text
./test-results/steamcmd-connectivity/
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
- Try public DNS override checks with Docker `--dns 1.1.1.1` and `--dns 8.8.8.8`.
- Try Docker Desktop host networking if it is available/enabled.
- Retest on the Rocky Linux Docker host as a clean comparison later. Do not attempt Rocky Linux, Unraid, or LAN connectivity tests from the local Codex host.

## Things Not To Do

- Do not switch to Wine as a workaround for this connectivity blocker.
- Do not mark download, launch, update, mod, or MVP behavior as working without real AppID `443030` files.
- Do not print tokens, passwords, or secrets in diagnostic output.
