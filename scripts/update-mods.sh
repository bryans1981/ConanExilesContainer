#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck source=scripts/common.sh
source /scripts/common.sh

backup_existing_modlist() {
    local modlist="$1"
    local backup_path

    if [[ -f "$modlist" ]]; then
        backup_path="${modlist}.backup.$(timestamp)"
        cp "$modlist" "$backup_path"
        log "Backed up existing mod list to ${backup_path}"
    fi
}

download_mods() {
    local mods=("$@")

    if [[ "${#mods[@]}" -eq 0 ]]; then
        return 0
    fi

    local cmd
    local steamcmd_mod_log
    local steamcmd_exit

    require_command "$STEAMCMD"
    ensure_dir "${LOG_DIR}/steamcmd"
    steamcmd_mod_log="${LOG_DIR}/steamcmd/update-mods-${WORKSHOP_APP_ID}-$(timestamp).log"

    log "Downloading/updating Workshop mods with SteamCMD: workshop_app_id=${WORKSHOP_APP_ID}, mod_count=${#mods[@]}, log=${steamcmd_mod_log}"
    cmd=(
        "$STEAMCMD"
        +@ShutdownOnFailedCommand 1
        +@NoPromptForPassword 1
        +force_install_dir "$STEAM_DIR"
        +login anonymous
    )

    for mod_id in "${mods[@]}"; do
        numeric_or_die "Workshop mod ID" "$mod_id"
        log "Queueing Workshop mod ${mod_id} for download/update."
        cmd+=(+workshop_download_item "$WORKSHOP_APP_ID" "$mod_id" validate)
    done

    cmd+=(+quit)
    set +e
    HOME="$STEAM_DIR" "${cmd[@]}" 2>&1 | tee "$steamcmd_mod_log"
    steamcmd_exit="${PIPESTATUS[0]}"
    set -e

    if [[ "$steamcmd_exit" -ne 0 ]]; then
        log "ERROR: SteamCMD Workshop download failed: workshop_app_id=${WORKSHOP_APP_ID}, mod_count=${#mods[@]}, exit_code=${steamcmd_exit}, log=${steamcmd_mod_log}"
        return "$steamcmd_exit"
    fi

    return 0
}

write_modlist() {
    local modlist="$1"
    shift
    local mods=("$@")
    local temp_modlist
    local item_dir
    local pak
    local paks_found

    temp_modlist="$(mktemp)"

    for mod_id in "${mods[@]}"; do
        item_dir="${STEAM_DIR}/steamapps/workshop/content/${WORKSHOP_APP_ID}/${mod_id}"
        [[ -d "$item_dir" ]] || die "Workshop mod ${mod_id} did not download to expected directory ${item_dir}"

        paks_found="false"
        while IFS= read -r pak; do
            printf '%s\n' "$pak" >> "$temp_modlist"
            paks_found="true"
            log "Added Workshop mod ${mod_id} pak to mod list: ${pak}"
        done < <(find "$item_dir" -type f -name '*.pak' -print | sort)

        [[ "$paks_found" == "true" ]] || die "Workshop mod ${mod_id} contains no .pak files under ${item_dir}"
    done

    mv "$temp_modlist" "$modlist"
    log "Wrote Conan mod list in requested order: ${modlist}"
}

prune_removed_mods() {
    local active_file="$1"
    shift
    local active_mods=("$@")
    local workshop_content="${STEAM_DIR}/steamapps/workshop/content/${WORKSHOP_APP_ID}"
    local active_set
    local mod_dir
    local mod_id

    if ! is_true "PRUNE_REMOVED_MODS" "${PRUNE_REMOVED_MODS:-true}"; then
        log "Prune disabled; old downloaded mods will remain on disk."
        return 0
    fi

    [[ -d "$workshop_content" ]] || return 0

    active_set="$(mktemp)"
    printf '%s\n' "${active_mods[@]}" > "$active_set"

    while IFS= read -r mod_dir; do
        mod_id="$(basename "$mod_dir")"
        if ! grep -Fxq "$mod_id" "$active_set"; then
            log "Pruning removed Workshop mod directory: ${mod_dir}"
            rm -rf "$mod_dir"
        fi
    done < <(find "$workshop_content" -mindepth 1 -maxdepth 1 -type d -print | sort)

    rm -f "$active_set"
    printf '%s\n' "${active_mods[@]}" > "$active_file"
}

main() {
    local mods_raw="${WORKSHOP_MOD_IDS:-}"
    local mod_dir="${SERVER_DIR}/ConanSandbox/Mods"
    local modlist="${mod_dir}/modlist.txt"
    local active_file="${mod_dir}/.active-workshop-mods"
    local mods=()
    local mod_id

    ensure_dir "$mod_dir"
    ensure_dir "$STEAM_DIR"

    while IFS= read -r mod_id; do
        mods+=("$mod_id")
    done < <(normalize_csv "$mods_raw")

    backup_existing_modlist "$modlist"

    if [[ "${#mods[@]}" -eq 0 ]]; then
        : > "$modlist"
        : > "$active_file"
        log "No WORKSHOP_MOD_IDS configured; active mod list is empty."
        return 0
    fi

    download_mods "${mods[@]}"
    write_modlist "$modlist" "${mods[@]}"
    prune_removed_mods "$active_file" "${mods[@]}"
}

main "$@"
