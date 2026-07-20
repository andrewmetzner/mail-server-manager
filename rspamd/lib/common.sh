#!/usr/bin/env bash
# Shared helpers for the rspamd migration scripts. Sourced, not executed.

set -euo pipefail
export PATH="$PATH:/usr/sbin:/sbin"

BACKUP_ROOT="/root/rspamd-migration-backups"
TS="$(date +%Y%m%d-%H%M%S)"

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; }

require_root() {
    if [[ $EUID -ne 0 ]]; then
        err "Run this as root: sudo bash $0"
        exit 1
    fi
}

# backup_file /etc/postfix/main.cf
# Copies the file into $BACKUP_ROOT/<script-name>-<timestamp>/ preserving path.
backup_file() {
    local src="$1"
    local script_name
    script_name="$(basename "${0%.sh}")"
    local dest_dir="${BACKUP_ROOT}/${script_name}-${TS}"
    mkdir -p "${dest_dir}$(dirname "$src")"
    if [[ -e "$src" ]]; then
        cp -a "$src" "${dest_dir}${src}"
        log "Backed up $src -> ${dest_dir}${src}"
    fi
}

confirm() {
    local prompt="${1:-Continue?}"
    read -r -p "${prompt} [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}
