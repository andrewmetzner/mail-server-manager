#!/bin/bash
# Lists pending invite tokens in /var/lib/mail-invites: which email each
# token maps to, how old it is, and when the hourly cleanup cron job
# (find -mmin +2880 -delete, i.e. 48h) will reap it.
set -uo pipefail

INVITE_DIR="/var/lib/mail-invites"
MAX_AGE_MIN=2880

echo "==> Pending invites in ${INVITE_DIR}"
FOUND=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  FOUND=1
  TOKEN="$(basename "$f")"
  EMAIL="$(sudo cat "$f")"
  AGE_MIN=$(( ( $(date +%s) - $(sudo stat -c %Y "$f") ) / 60 ))
  REMAINING=$(( MAX_AGE_MIN - AGE_MIN ))
  if [ "$REMAINING" -le 0 ]; then
    STATUS="expired, awaiting cleanup"
  else
    STATUS="expires in $((REMAINING / 60))h $((REMAINING % 60))m"
  fi
  printf '%s  ->  %-30s  (%dm old, %s)\n' "$TOKEN" "$EMAIL" "$AGE_MIN" "$STATUS"
done < <(sudo find "$INVITE_DIR" -maxdepth 1 -type f 2>/dev/null)

if [ "$FOUND" -eq 0 ]; then
  echo "(none)"
fi
