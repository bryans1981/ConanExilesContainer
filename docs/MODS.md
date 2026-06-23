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
- Mods are downloaded with the selected `MOD_DOWNLOAD_BACKEND` using Workshop app ID `440900`.
- The generated active mod list is `ConanSandbox/Mods/modlist.txt`.
- The mod list preserves the order from `WORKSHOP_MOD_IDS`.
- The previous mod list is backed up before being replaced.
- Any failed mod download fails the container startup clearly.
- SteamCMD Workshop output is captured to timestamped logs under `/serverdata/logs/steamcmd/`.
- DepotDownloader Workshop output is captured to timestamped logs under `/serverdata/logs/depotdownloader/`.

`PRUNE_REMOVED_MODS=true` removes downloaded Workshop directories that are no longer listed. `PRUNE_REMOVED_MODS=false` leaves old downloads on disk but removes them from the active mod list.

## Backend Selection

`MOD_DOWNLOAD_BACKEND` supports:

- `depotdownloader`: use DepotDownloader only. This is the default.
- `steamcmd`: use SteamCMD only. Use this on hosts where Linux SteamCMD works.
- `auto`: try DepotDownloader first, then log the failure and try SteamCMD.

There is no silent fallback. If a listed mod cannot be downloaded or no `.pak` files are found for that mod, startup fails clearly.

## Verified Behavior

Verified on June 23, 2026 with DepotDownloader under Docker default security:

- Public test item: `3720546346` (`[Enhanced] Unlimited Weight`).
- DepotDownloader command shape: `DepotDownloader -app 440900 -pubfile 3720546346`.
- Integrated project backend: `MOD_DOWNLOAD_BACKEND=depotdownloader`.
- Verified `.pak`: `HEUnlimitedWeight.pak`.
- Generated modlist path: `ConanSandbox/Mods/modlist.txt`.
- Generated modlist line format in this project: absolute `.pak` path, for example `/serverdata/steam/steamapps/workshop/content/440900/3720546346/HEUnlimitedWeight.pak`.
- Active mod state file: `ConanSandbox/Mods/.active-workshop-mods`.
- A clean local compose e2e run downloaded the mod, generated the modlist, started the server to `StartPlay`, stopped gracefully, and restarted without wiping the modlist.

Also verified on June 23, 2026 with diagnostic `seccomp=unconfined`:

- Public test item: `3720546346` (`[Enhanced] Unlimited Weight`), Steam API reported `312179` bytes.
- SteamCMD downloaded the item to `steamapps/workshop/content/440900/3720546346`.
- Verified `.pak`: `HEUnlimitedWeight.pak`.
- Generated modlist path: `ConanSandbox/Mods/modlist.txt`.
- Generated modlist line format in this project: absolute `.pak` path.

Verification still required:

- Confirm multi-mod ordering with more than one real mod.
- Confirm removing a mod ID updates the active mod list.
- Confirm pruning behavior with real downloaded mods.
