# WebGUI Phase 2

The WebGUI is not part of the MVP and must not block server container testing.

Future WebGUI capabilities:

- Server running/stopped status.
- Current server build/version if detectable.
- Active mod list.
- Last update result.
- Last backup result.
- Log viewer.
- Edit common settings.
- Trigger backup.
- Trigger server update.
- Trigger mod update.
- Restart server.
- Display connection ports.
- Basic authentication if exposed beyond trusted local access.

Security notes:

- Do not expose the WebGUI publicly without authentication.
- Never display passwords or secrets.
- Avoid write operations without clear user confirmation.
