# Troubleshooting Server Listing

Use this guide when the Docker Desktop Conan server reaches `StartPlay` but does not appear in the Conan Exiles in-game server browser from another LAN client, or when direct LAN login/password behavior needs to be rechecked.

Do not treat browser absence as proof that the server is down. Direct LAN connectivity, Steam/query response, and public/server-browser registration can fail independently.

## Current Evidence

Local Docker Desktop diagnostics on June 24, 2026 verified:

- Container `conan-exiles-container` was running and healthy.
- Server readiness marker `StartPlay` appeared in logs.
- Docker published `7777/udp`, `7778/udp`, `27015/udp`, and `25575/tcp`.
- The server listened inside the container on `7777/udp`, `7778/udp`, and `27015/udp`.
- SourceServerQueries started on `27015`.
- The launch command included `-log -QueryPort=27015`.
- Host UDP ports `7777`, `7778`, and `27015` were owned by Docker Desktop's backend process.
- No old Windows Dedicated Server Launcher, Conan, or host SteamCMD process candidates were found.
- No specific Windows Firewall inbound rules existed for the Docker-published Conan ports.

Important clues from the original investigation:

- Logs included `Autologin attempt failed, unable to register server!`
- Logs included `SteamSockets: Disabled due to no Steam OSS running.`
- Before the config fix, generated `ServerSettings.ini` had the requested local live server name, but the Conan startup report still showed `Name=Conan Exiles Server`.
- After writing `SERVER_NAME` and `SERVER_PASSWORD` to active `Engine.ini` section `[OnlineSubsystem]`, the startup report showed `Name=WickedServerContianer`.
- After setting `SERVER_REGION=America`, the startup report showed `Region=1`, and the user confirmed the client displayed the corrected America region.

User-confirmed on June 24, 2026: the LAN client can see the server, log in, use the configured server/admin passwords, and shows America/North America region.

## Run Diagnostics

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\local-lan-server-diagnostics.ps1 -EnvFile .env.local-live
```

This reports:

- Windows host LAN IPv4 addresses.
- Docker context and compose service state.
- Docker-published ports.
- In-container sockets.
- Host port owners and possible old Conan processes.
- Windows Firewall rule status.
- Recent listing/query log findings.
- Active config path and required local live name/password config keys.
- Password leak scan result.
- Local data disk usage.
- Exact other-LAN-client test targets.

## Required Ports

- `7777/udp`: game traffic.
- `7778/udp`: pinger, normally game port plus one.
- `27015/udp`: Steam/server query.
- `25575/tcp`: RCON, only when RCON is enabled.

Docker publishing alone is not always enough for another LAN client. Windows Firewall can still block inbound traffic to Docker Desktop's backend.

## Windows Firewall

Check-only mode:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\windows-firewall-conan-rules.ps1 -EnvFile .env.local-live
```

Apply narrow inbound allow rules from an Administrator PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\windows-firewall-conan-rules.ps1 -EnvFile .env.local-live -Apply
```

Remove only those named rules from an Administrator PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\windows-firewall-conan-rules.ps1 -EnvFile .env.local-live -Remove
```

The helper creates only named rules for the configured Conan ports. It does not open broad ranges.

## Client Tests

From the other LAN client system:

```text
Direct connect: <windows-docker-host-lan-ip>:7777
Steam/query favorite if supported: <windows-docker-host-lan-ip>:27015
Server browser search: WickedServerContianer
```

Enable:

- Show Invalid
- Show Private
- Show With Mods

If direct LAN connect fails, prioritize Windows Firewall, host network profile, Docker Desktop networking, port ownership, and VPN/proxy/security software checks.

If direct LAN connect works but entry is allowed with no password, or the region/name is wrong, basic LAN/game-port traffic is working. Check env/config application before focusing on server-browser listing:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\local-env-effective-diagnostics.ps1 -EnvFile .env.local-live
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\conan-config-effective-diagnostics.ps1 -EnvFile .env.local-live
```

For the Linux server, the active config path is `/serverdata/config/ConanSandbox/Saved/Config/LinuxServer`, linked into `/serverdata/serverfiles/ConanSandbox/Saved/Config/LinuxServer`. The managed server name and server password live in `Engine.ini` section `[OnlineSubsystem]`, and are also mirrored to `ServerSettings.ini` section `[ServerSettings]`.

If direct LAN connect works but browser listing fails, prioritize query-port behavior, registration warnings, server name mismatch, private/listing settings, and upstream Conan/Funcom listing behavior.

## Multihome And Query Args

The normal launch includes `-QueryPort=<QUERY_PORT>` when `FORCE_QUERY_PORT_ARG=true`.

Optional diagnostics:

```env
MULTIHOME_IP=
MULTIHOME_HTTP_IP=
```

Set these only in ignored local env files when explicitly testing host/IP binding. Do not hardcode machine-specific LAN IP addresses into committed files.

## Report Back

Report:

- Whether direct connect to the Windows Docker host LAN IP and game port works.
- Whether direct connect requires a password.
- Whether the configured local test password is accepted or rejected.
- Whether the query/favorite test works, if supported.
- Whether `WickedServerContianer` appears in the browser.
- Whether the password prompt appears.
- Whether the password is accepted.
- Whether character creation/login reaches the server.
- Any exact client error text.
- Whether Docker logs show a connection attempt during the test.
