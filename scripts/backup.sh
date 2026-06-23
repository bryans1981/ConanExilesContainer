#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=scripts/common.sh
source /scripts/common.sh

cleanup_retention() {
    local current_archive="$1"
    local days="${BACKUP_RETENTION_DAYS:-14}"
    local old_backup

    positive_or_zero_or_die "BACKUP_RETENTION_DAYS" "$days"
    if [[ "$days" -eq 0 ]]; then
        log "Backup retention cleanup disabled because BACKUP_RETENTION_DAYS=0."
        return 0
    fi

    while IFS= read -r old_backup; do
        if [[ "$old_backup" == "$current_archive" ]]; then
            continue
        fi
        log "Removing backup older than ${days} days: ${old_backup}"
        rm -f "$old_backup"
    done < <(find "$BACKUP_LOCATION" -maxdepth 1 -type f -name 'conan-backup-*.tar.gz' -mtime +"$days" -print | sort)
}

main() {
    local reason="${1:-manual}"
    local ts
    local archive
    local paths=()

    ensure_dir "$BACKUP_LOCATION"
    ts="$(timestamp)"
    archive="${BACKUP_LOCATION}/conan-backup-${ts}-${reason}.tar.gz"

    [[ -d "$CONFIG_DIR" ]] && paths+=("serverdata/config")
    [[ -d "${SERVER_DIR}/ConanSandbox/Saved" ]] && paths+=("serverdata/serverfiles/ConanSandbox/Saved")
    [[ -f "${SERVER_DIR}/ConanSandbox/Mods/modlist.txt" ]] && paths+=("serverdata/serverfiles/ConanSandbox/Mods/modlist.txt")
    [[ -f "${SERVER_DIR}/ConanSandbox/Mods/.active-workshop-mods" ]] && paths+=("serverdata/serverfiles/ConanSandbox/Mods/.active-workshop-mods")
    [[ -f "${SERVER_DIR}/steamapps/appmanifest_${APP_ID}.acf" ]] && paths+=("serverdata/serverfiles/steamapps/appmanifest_${APP_ID}.acf")

    if [[ "${#paths[@]}" -eq 0 ]]; then
        log "No backup source paths exist yet; skipping backup."
        cleanup_retention ""
        return 0
    fi

    log "Creating backup archive: ${archive}"
    tar -czf "$archive" -C / "${paths[@]}"
    log "Backup complete: ${archive}"

    cleanup_retention "$archive"
}

main "$@"
