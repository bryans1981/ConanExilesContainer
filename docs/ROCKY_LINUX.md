# Rocky Linux

Rocky Linux testing starts after local Docker Desktop testing succeeds.

Expected flow:

```bash
git clone https://github.com/<YOUR_GITHUB_USER>/ConanExilesContainer.git
cd ConanExilesContainer
docker compose build
docker compose up -d
docker compose logs -f
```

The repository includes a safe committed `.env`. Edit it or provide host/Compose overrides before first start. Do not commit real server passwords or machine-specific paths.

Host notes:

- Use Docker Engine with the compose plugin.
- Keep the same container paths.
- Use normal Rocky Linux filesystem paths for bind mounts if not running from the repo root.
- Ensure UDP `7777`, UDP `7778`, UDP `27015`, and TCP `25575` are open in the host firewall when needed.
- Do not publish TCP `8080` until a future WebGUI exists and has authentication.

Current Rocky Linux test status: not started.

Rocky Linux may be the next practical verification host because Docker Desktop on the current Windows host can start SteamCMD but cannot complete Steam anonymous login.

After testing, record host differences and results here and in `SESSION_HANDOFF.md`.
