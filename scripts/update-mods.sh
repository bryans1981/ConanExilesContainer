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

    local backend
    local steamcmd_exit
    local depotdownloader_exit

    backend="$(mod_download_backend_value "${MOD_DOWNLOAD_BACKEND:-depotdownloader}")"
    log "Selected Workshop mod download backend: ${backend}"

    case "$backend" in
        steamcmd)
            download_mods_with_steamcmd "${mods[@]}"
            ;;
        depotdownloader)
            download_mods_with_depotdownloader "${mods[@]}"
            ;;
        auto)
            log "MOD_DOWNLOAD_BACKEND=auto: trying DepotDownloader first."
            set +e
            download_mods_with_depotdownloader "${mods[@]}"
            depotdownloader_exit="$?"
            set -e
            if [[ "$depotdownloader_exit" -eq 0 ]]; then
                log "MOD_DOWNLOAD_BACKEND=auto: DepotDownloader succeeded; SteamCMD fallback not used."
                return 0
            fi

            log "MOD_DOWNLOAD_BACKEND=auto: DepotDownloader failed with exit_code=${depotdownloader_exit}. Trying SteamCMD fallback."
            set +e
            download_mods_with_steamcmd "${mods[@]}"
            steamcmd_exit="$?"
            set -e
            if [[ "$steamcmd_exit" -ne 0 ]]; then
                die "MOD_DOWNLOAD_BACKEND=auto failed. DepotDownloader exit_code=${depotdownloader_exit}; SteamCMD exit_code=${steamcmd_exit}."
            fi
            ;;
    esac
}

download_mods_with_steamcmd() {
    local mods=("$@")
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

download_mods_with_depotdownloader() {
    local mods=("$@")
    local depotdownloader_mod_log
    local depotdownloader_exit
    local mod_id
    local item_dir

    require_executable "$DEPOTDOWNLOADER"
    ensure_dir "${LOG_DIR}/depotdownloader"
    depotdownloader_mod_log="${LOG_DIR}/depotdownloader/update-mods-${WORKSHOP_APP_ID}-$(timestamp).log"

    log "Downloading/updating Workshop mods with DepotDownloader ${DEPOTDOWNLOADER_VERSION}: workshop_app_id=${WORKSHOP_APP_ID}, mod_count=${#mods[@]}, log=${depotdownloader_mod_log}"
    : > "$depotdownloader_mod_log"

    for mod_id in "${mods[@]}"; do
        numeric_or_die "Workshop mod ID" "$mod_id"
        item_dir="${STEAM_DIR}/steamapps/workshop/content/${WORKSHOP_APP_ID}/${mod_id}"
        ensure_dir "$item_dir"
        log "Downloading Workshop mod ${mod_id} with DepotDownloader to ${item_dir}."
        {
            printf '[%s] DepotDownloader Workshop mod %s start: app_id=%s, dir=%s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$mod_id" "$WORKSHOP_APP_ID" "$item_dir"
            HOME="$STEAM_DIR" "$DEPOTDOWNLOADER" \
                -app "$WORKSHOP_APP_ID" \
                -pubfile "$mod_id" \
                -dir "$item_dir"
        } 2>&1 | tee -a "$depotdownloader_mod_log"
        depotdownloader_exit="${PIPESTATUS[0]}"
        if [[ "$depotdownloader_exit" -ne 0 ]]; then
            log "ERROR: DepotDownloader Workshop download failed: workshop_app_id=${WORKSHOP_APP_ID}, mod_id=${mod_id}, exit_code=${depotdownloader_exit}, log=${depotdownloader_mod_log}"
            return "$depotdownloader_exit"
        fi
    done

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
        printf '%s\n' "${active_mods[@]}" > "$active_file"
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
