#!/bin/bash
# Dumps the root-owned, execute-only invite scripts (and related state)
# into a readable txt file for review, since they can't be cat'd without sudo.
set -uo pipefail

OUT="$(dirname "$(readlink -f "$0")")/invite-scripts-dump.txt"

{
  echo "=== $(date) ==="
  echo
  echo "=== /usr/local/bin/mail-invite-create.sh ==="
  sudo cat /usr/local/bin/mail-invite-create.sh
  echo
  echo "=== /usr/local/bin/mail-add-user.sh ==="
  sudo cat /usr/local/bin/mail-add-user.sh
  echo
  echo "=== /usr/local/bin/mail-del-user.sh ==="
  cat /usr/local/bin/mail-del-user.sh
  echo
  echo "=== sudoers entries for www-data / invite scripts ==="
  sudo grep -rn "www-data\|mail-add-user\|mail-invite-create\|mail-del-user" /etc/sudoers /etc/sudoers.d/ 2>/dev/null
  echo
  echo "=== /var/lib/mail-invites (pending invite tokens) ==="
  sudo ls -la /var/lib/mail-invites/
  echo
  echo "--- token contents (email each token maps to) ---"
  for f in /var/lib/mail-invites/*; do
    [ -f "$f" ] || continue
    printf '%s -> ' "$(basename "$f")"
    sudo cat "$f"
    echo
  done
  echo
  echo "=== root crontab ==="
  sudo crontab -l 2>&1
  echo
  echo "=== /var/log/invite_cleanup.log ==="
  sudo cat /var/log/invite_cleanup.log 2>&1
} > "$OUT" 2>&1

echo "Wrote dump to $OUT"
