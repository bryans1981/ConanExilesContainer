# Backups

Backups are timestamped `.tar.gz` archives in `BACKUP_LOCATION`, defaulting to `/serverdata/backups`.

Included when present:

- `/serverdata/config`
- `/serverdata/serverfiles/ConanSandbox/Saved`
- `/serverdata/serverfiles/ConanSandbox/Mods/modlist.txt`
- `/serverdata/serverfiles/ConanSandbox/Mods/.active-workshop-mods`
- `/serverdata/serverfiles/steamapps/appmanifest_443030.acf`

Startup backups:

- `BACKUP_ON_START=true` creates a backup before startup update/mod operations when existing data is present.

Shutdown backups:

- `BACKUP_ON_STOP=true` creates a backup during graceful container shutdown.

Retention:

- `BACKUP_RETENTION_DAYS=14` removes backup archives older than 14 days.
- `BACKUP_RETENTION_DAYS=0` disables cleanup.
- Every removed archive is logged.

Basic restore:

1. Stop the container.
2. Copy the current `./data` folder aside.
3. Extract the chosen backup archive from repo root or another directory that contains `serverdata/`.
4. Copy restored paths back into the corresponding `./data` folders.
5. Start the container and verify logs.

Do not delete backup archives unless you are sure they are no longer needed.
