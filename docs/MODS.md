# Workshop Mods

`WORKSHOP_MOD_IDS` is a comma-separated ordered list of Steam Workshop item IDs.

Example:

```env
WORKSHOP_MOD_IDS=123456789,987654321
```

Behavior:

- Whitespace is trimmed.
- Empty entries are ignored.
- Each ID must be numeric.
- Mods are downloaded with SteamCMD using Workshop app ID `440900`.
- The generated active mod list is `ConanSandbox/Mods/modlist.txt`.
- The mod list preserves the order from `WORKSHOP_MOD_IDS`.
- The previous mod list is backed up before being replaced.
- Any failed mod download fails the container startup clearly.

`PRUNE_REMOVED_MODS=true` removes downloaded Workshop directories that are no longer listed. `PRUNE_REMOVED_MODS=false` leaves old downloads on disk but removes them from the active mod list.

Verification still required:

- Confirm Workshop app ID `440900` is correct for Conan Exiles Enhanced mods.
- Confirm AppID `443030` expects `ConanSandbox/Mods/modlist.txt`.
- Confirm whether modlist entries should be absolute `.pak` paths or server-relative paths.
- Confirm Workshop downloads once SteamCMD anonymous login works from the Docker host.
