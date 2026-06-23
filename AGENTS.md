# Agent Working Rules

This project is the `ConanExilesContainer` Docker container for a Conan Exiles Enhanced dedicated server.

Rules for Codex and future agents:

- Do not guess. Verify actual server files, executable names, paths, config files, launch syntax, Workshop mod behavior, and modlist behavior from downloaded AppID `443030` files before claiming MVP success.
- Native Linux dedicated server files are the default target.
- Do not start with Wine. Wine may only be added later as an optional fallback if native Linux server files are proven unusable and the user approves that direction.
- Do not fake incomplete features. Planned features must be marked as planned/not active.
- Do not overwrite saves or custom config. Generate defaults only when files are missing, and preserve existing files before linking or changing runtime locations.
- Keep passwords and secrets out of logs.
- Keep `AGENTS.md`, `PROJECT.md`, `PROJECT_MAP.md`, and `SESSION_HANDOFF.md` updated after meaningful changes.
- Run local Docker Desktop testing before claiming MVP success.
- Do not attempt LAN, Rocky Linux, or Unraid connectivity tests from the local Codex host. This environment has public internet access only and no LAN access by design.
- When SteamCMD connectivity fails, compare host public internet, generic container internet/DNS, the project image, and the upstream SteamCMD image before changing app logic.
- Prefer small, testable changes.
- Keep the image generic and portable. Do not hardcode host-specific paths.
- Update `SESSION_HANDOFF.md` before stopping work.

## GitHub Automation

- When the user asks to create a project/repo, commit, push, or publish work, first attempt automated GitHub repo creation, remote setup, commit, and push using available authenticated tooling.
- Do not default to manual GitHub instructions.
- Use private repositories by default unless the user explicitly approves public visibility.
- Detect the intended GitHub owner from authenticated `gh`, git, Git Credential Manager, or connector context when possible. If no owner can be safely detected for this project, use `bryans1981`.
- Do not print tokens or secrets.
- If `gh` is unavailable, check normal git remotes, Git Credential Manager, and any available authenticated GitHub connector/API path before falling back to manual instructions.
- If automation fails, document the exact blocker, commands or methods attempted, and safest next manual step in `SESSION_HANDOFF.md`.

Current implementation notes:

- AppID `443030` is used for server install/update.
- SteamCMD is the first install method, using the `steamcmd/steamcmd:ubuntu-24` base image.
- The entrypoint seeds `/serverdata/steam` with the base image's bootstrapped SteamCMD home so SteamCMD can run as the configured non-root user.
- The container explicitly requests Linux platform files from SteamCMD and fails if only Windows server executables are found.
- Auto game update and auto mod update variables exist but the background loops are not active in the MVP.
