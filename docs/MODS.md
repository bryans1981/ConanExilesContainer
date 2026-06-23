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
- SteamCMD Workshop output is captured to timestamped logs under `/serverdata/logs/steamcmd/`.

`PRUNE_REMOVED_MODS=true` removes downloaded Workshop directories that are no longer listed. `PRUNE_REMOVED_MODS=false` leaves old downloads on disk but removes them from the active mod list.

DepotDownloader note:

- Server-file DepotDownloader support does not currently change Workshop mod behavior.
- A diagnostic DepotDownloader `-pubfile` manifest-only check against public Conan Workshop item `880454836` reached Steam anonymously with `-app 440900`.
- A later full DepotDownloader `-pubfile` download for public item `3720546346` succeeded once and produced `HEUnlimitedWeight.pak`, but immediate integrated retries failed to connect to Steam.
- `MOD_DOWNLOAD_BACKEND` is not implemented.

Verified on June 23, 2026 with diagnostic `seccomp=unconfined`:

- Public test item: `3720546346` (`[Enhanced] Unlimited Weight`), Steam API reported `312179` bytes.
- SteamCMD downloaded the item to `steamapps/workshop/content/440900/3720546346`.
- Verified `.pak`: `HEUnlimitedWeight.pak`.
- Generated modlist path: `ConanSandbox/Mods/modlist.txt`.
- Generated modlist line format in this project: absolute `.pak` path, for example `/diagnostics/steam/steamapps/workshop/content/440900/3720546346/HEUnlimitedWeight.pak`.

Verification still required:

- Confirm live server-side mod loading from `ConanSandbox/Mods/modlist.txt`.
- Confirm multi-mod ordering with more than one real mod.
- Confirm removing a mod ID updates the active mod list.
- Confirm pruning behavior with real downloaded mods.
