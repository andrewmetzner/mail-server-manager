#!/bin/bash
# Manage mail forwarding/aliases in /etc/postfix/virtual.
#
# Usage:
#   ./mail-forward.sh list
#   ./mail-forward.sh set <address> <dest1>[,<dest2>,...]
#   ./mail-forward.sh remove <address>
#
# Notes:
# - To forward AND keep a local copy, include the address itself in the
#   destination list, e.g.:
#     ./mail-forward.sh set you@example.com you@example.com,backup@example.com
# - To forward-only (no local copy), just omit the address from the destination list.
# - Always recompiles the map (postmap) and reloads postfix after a change.
set -euo pipefail

VIRTUAL_FILE="/etc/postfix/virtual"
CMD="${1:-}"

usage() {
  echo "Usage:"
  echo "  $0 list"
  echo "  $0 set <address> <dest1>[,<dest2>,...]"
  echo "  $0 remove <address>"
  exit 1
}

backup() {
  sudo cp "$VIRTUAL_FILE" "${VIRTUAL_FILE}.bak-$(date +%Y%m%d%H%M%S)"
}

recompile_and_reload() {
  sudo postmap "$VIRTUAL_FILE"
  sudo postfix check && echo "postfix config OK"
  sudo systemctl reload postfix
}

case "$CMD" in
  list)
    echo "==> Current entries in ${VIRTUAL_FILE}:"
    sudo cat -A "$VIRTUAL_FILE" | sed 's/\$$//'
    ;;

  set)
    [ $# -eq 3 ] || usage
    ADDRESS="$2"
    DESTS="$3"
    echo "==> Backing up ${VIRTUAL_FILE}"
    backup
    echo "==> Removing any existing line(s) for ${ADDRESS}"
    sudo awk -v addr="$ADDRESS" '$1 != addr' "$VIRTUAL_FILE" | sudo tee "${VIRTUAL_FILE}.tmp" > /dev/null
    echo "==> Adding new entry"
    printf '%s\t%s\n' "$ADDRESS" "$DESTS" | sudo tee -a "${VIRTUAL_FILE}.tmp" > /dev/null
    sudo mv "${VIRTUAL_FILE}.tmp" "$VIRTUAL_FILE"
    sudo chown root:root "$VIRTUAL_FILE"
    sudo chmod 644 "$VIRTUAL_FILE"
    recompile_and_reload
    echo "==> ${ADDRESS} now forwards to: ${DESTS}"
    ;;

  remove)
    [ $# -eq 2 ] || usage
    ADDRESS="$2"
    echo "==> Backing up ${VIRTUAL_FILE}"
    backup
    echo "==> Removing line(s) for ${ADDRESS}"
    sudo awk -v addr="$ADDRESS" '$1 != addr' "$VIRTUAL_FILE" | sudo tee "${VIRTUAL_FILE}.tmp" > /dev/null
    sudo mv "${VIRTUAL_FILE}.tmp" "$VIRTUAL_FILE"
    sudo chown root:root "$VIRTUAL_FILE"
    sudo chmod 644 "$VIRTUAL_FILE"
    recompile_and_reload
    echo "==> Removed forwarding for ${ADDRESS}"
    ;;

  *)
    usage
    ;;
esac
