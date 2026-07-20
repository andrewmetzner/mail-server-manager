#!/bin/bash
# Lists pending password-reset tokens in /var/lib/mail-password-resets:
# which mailbox each token maps to, how old it is, and whether it's still
# valid (tokens self-expire after 60 minutes per forgot-password.php,
# independent of any cron sweep -- see root crontab).
set -uo pipefail

RESET_DIR="/var/lib/mail-password-resets"

echo "==> Pending password resets in ${RESET_DIR}"
FOUND=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  FOUND=1
  TOKEN="$(basename "$f")"
  EMAIL="$(sudo sed -n '1p' "$f")"
  EXPIRES="$(sudo sed -n '2p' "$f")"
  NOW=$(date +%s)
  if [ -z "$EXPIRES" ] || [ "$NOW" -ge "$EXPIRES" ]; then
    STATUS="expired, awaiting cleanup"
  else
    REMAINING=$(( (EXPIRES - NOW) / 60 ))
    STATUS="expires in ${REMAINING}m"
  fi
  printf '%s  ->  %-30s  (%s)\n' "$TOKEN" "$EMAIL" "$STATUS"
done < <(sudo find "$RESET_DIR" -maxdepth 1 -type f 2>/dev/null)

if [ "$FOUND" -eq 0 ]; then
  echo "(none)"
fi
