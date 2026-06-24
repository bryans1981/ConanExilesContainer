# Local Live Client Test

Use this workflow when the goal is to run the Docker Desktop server locally and connect from a Conan Exiles game client on another machine on the same LAN.

Do not use this workflow for Rocky Linux, Unraid, or WebGUI work.

## 1. Create Local Env File

Create an ignored local env file from the repository root:

```powershell
Copy-Item .env .env.local-live
```

Edit `.env.local-live` for the live test:

```env
SERVER_NAME=WickedServerContianer
SERVER_PASSWORD=<local-test-password>
ADMIN_PASSWORD=<local-test-password>
DOWNLOAD_BACKEND=depotdownloader
MOD_DOWNLOAD_BACKEND=depotdownloader
GAME_PORT=7777
PINGER_PORT=7778
QUERY_PORT=27015
FORCE_QUERY_PORT_ARG=true
SERVER_REGION=America
MULTIHOME_IP=
MULTIHOME_HTTP_IP=
RCON_ENABLED=true
RCON_PORT=25575
RCON_PASSWORD=<local-test-password>
UPDATE_SERVER_ON_START=true
UPDATE_MODS_ON_START=true
WORKSHOP_MOD_IDS=
BACKUP_ON_START=true
BACKUP_ON_STOP=true
```

The local env file is intentionally ignored by git and Docker build context. Do not commit real local test passwords.

## 2. Validate Compose

Use quiet config output so password values are not printed:

```powershell
docker compose config --quiet
docker compose --env-file .env.local-live config --quiet
```

## 3. Start The Server

Start or update the local live server:

```powershell
docker compose --env-file .env.local-live up -d --build
```

This uses the normal secure Docker profile. Do not add the SteamCMD `seccomp=unconfined` diagnostic override for this DepotDownloader default flow.

## 4. Check Status

Show compose service status:

```powershell
docker compose --env-file .env.local-live ps
```

Run the local status helper:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\local-live-status.ps1 -EnvFile .env.local-live
```

Run the local durability helper before publishing or moving to another host:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\local-durability.ps1 -EnvFile .env.local-live -Quick -KeepRunning
```

Run the LAN-focused diagnostic helper:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\local-lan-server-diagnostics.ps1 -EnvFile .env.local-live
```

If direct LAN connect works but the server does not require the expected password, run the masked env/config diagnostics:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\local-env-effective-diagnostics.ps1 -EnvFile .env.local-live
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\conan-config-effective-diagnostics.ps1 -EnvFile .env.local-live
```

The helper checks:

- Compose container status.
- Published ports.
- Recent logs for `StartPlay`.
- Recent fatal startup patterns.
- Password value leaks in retained logs.
- Local `data/` disk usage.

The durability helper additionally checks graceful stop/start behavior, active config persistence, save/config directory persistence, backup creation, `UPDATE_SERVER_ON_START` durability, and modlist path validity. It does not delete live server data.

The LAN diagnostic additionally checks:

- Windows host LAN IPv4 addresses.
- Docker-published UDP/TCP ports.
- In-container UDP listeners for the game, pinger, and query ports.
- Host port ownership and old Conan/Dedicated Server Launcher process candidates.
- Windows Firewall rule status.
- Query/listing log clues such as SourceServerQueries startup and registration warnings.
- Active config path and required local live name/password config keys.

The active Linux server config path is:

```text
/serverdata/config/ConanSandbox/Saved/Config/LinuxServer
```

It is linked into:

```text
/serverdata/serverfiles/ConanSandbox/Saved/Config/LinuxServer
```

The managed server name and server password are written to `Engine.ini` section `[OnlineSubsystem]` on container startup. They are also mirrored to `ServerSettings.ini` section `[ServerSettings]`.

`SERVER_REGION=America` sets Conan's `serverRegion` to `1`, which the Conan client displays as America/North America. Numeric values are also accepted. The verified mapping from the Windows Dedicated Server Launcher is:

- `0`: Europe
- `1`: North America
- `2`: Asia
- `3`: Australia
- `4`: South America
- `5`: Japan

## 5. View Logs

Follow logs while the client tries to connect:

```powershell
docker compose --env-file .env.local-live logs -f --tail 200 conan
```

Read recent logs without following:

```powershell
docker compose --env-file .env.local-live logs --tail 400 conan
```

The ready marker to look for is `StartPlay`.

## 6. Confirm Ports

The status helper checks port publishing automatically. You can also inspect compose output:

```powershell
docker compose --env-file .env.local-live ps
```

Expected published ports:

- `7777/udp`: game traffic
- `7778/udp`: pinger
- `27015/udp`: Steam query
- `25575/tcp`: RCON, when enabled

## 7. Check Windows Firewall

The Docker Desktop backend can own the published ports even when no narrow Windows Firewall allow rule exists. Check-only mode does not change firewall state:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\windows-firewall-conan-rules.ps1 -EnvFile .env.local-live
```

To create or update only the named Conan rules, run from an Administrator PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\windows-firewall-conan-rules.ps1 -EnvFile .env.local-live -Apply
```

To remove only those named rules later, run from an Administrator PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\windows-firewall-conan-rules.ps1 -EnvFile .env.local-live -Remove
```

## 8. Connect From Conan Exiles Client

From the other LAN client system, try direct connect to the Windows Docker host LAN IP and game port:

```text
<windows-docker-host-lan-ip>:7777
```

If the game/client supports Steam favorite or query-style entry, try the query port:

```text
<windows-docker-host-lan-ip>:27015
```

Then try the in-game server browser:

```text
WickedServerContianer
```

Enable `Show Invalid`, `Show Private`, and `Show With Mods`. Use the local test password from `.env.local-live`.

Server missing from the browser does not automatically mean the server is down. Direct LAN connection and server-browser registration can fail for different reasons.

Direct LAN connect working but allowing entry with no password means the game-port path is working and env/config application should be checked before spending more time on firewall or browser listing.

## 9. Stop Or Restart

Stop without deleting data:

```powershell
docker compose --env-file .env.local-live stop
```

Restart without wiping data:

```powershell
docker compose --env-file .env.local-live up -d
```

Remove the running container while keeping mapped `./data` folders:

```powershell
docker compose --env-file .env.local-live down
```

Do not delete `./data` unless you intentionally want to remove local server files, saves, config, logs, Steam cache, mods, and backups.

## 10. What To Report Back

After trying the game client, report:

- Whether `WickedServerContianer` appears in the server browser.
- Whether direct connect to `<windows-docker-host-lan-ip>:7777` works.
- Whether direct connect requires a password.
- Whether query/favorite entry with `<windows-docker-host-lan-ip>:27015` works, if supported.
- Whether the configured local test password is accepted or rejected.
- Whether the server region shows America/North America instead of EU.
- Whether character creation/login reaches the server.
- Any exact client error text.
- Whether connection attempts appear in Docker logs.

Confirmed on June 24, 2026: the LAN client can see the server, log in, use the configured server/admin passwords, and shows the corrected America region.
