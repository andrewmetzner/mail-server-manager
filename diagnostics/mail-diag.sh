#!/bin/bash
# Dumps mail server diagnostic info to a text file for review.
set -uo pipefail

OUT="$(dirname "$(readlink -f "$0")")/mail-diag-output.txt"

{
  echo "=== $(date) ==="
  echo
  echo "=== /etc/dovecot/users ==="
  sudo cat /etc/dovecot/users
  echo
  echo "=== doveconf -n validity ==="
  if sudo doveconf -n >/dev/null 2>&1; then
    echo "dovecot config OK"
  else
    echo "dovecot config BROKEN:"
    sudo doveconf -n
  fi
  echo
  echo "=== postfix check ==="
  sudo postfix check && echo "postfix config OK"
  echo
  echo "=== dovecot journal (last 60 lines) ==="
  sudo journalctl -u dovecot --no-pager -n 60
  echo
  echo "=== postfix journal (last 60 lines) ==="
  sudo journalctl -u postfix@- --no-pager -n 60
  echo
  echo "=== fail2ban jail status ==="
  for jail in dovecot postfix sasl sshd; do
    echo "--- $jail ---"
    sudo fail2ban-client status "$jail"
  done
} > "$OUT" 2>&1

echo "Wrote diagnostics to $OUT"
