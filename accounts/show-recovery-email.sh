#!/bin/bash
# Looks up the recovery email stored for a mailbox (written by invite.php at
# signup time into /var/lib/mail-recovery/<mailbox>). Useful for verifying
# the invite flow stored it correctly, and as the address to pass to
# recover-mail-password.sh later.
#
# Usage: ./show-recovery-email.sh user@domain.com
set -euo pipefail

RECOVERY_DIR="/var/lib/mail-recovery"

if [ $# -ne 1 ]; then
  echo "Usage: $0 user@domain.com"
  exit 1
fi
EMAIL="$1"
FILE="${RECOVERY_DIR}/${EMAIL}"

if ! sudo test -f "$FILE"; then
  echo "No recovery email on file for ${EMAIL}."
  exit 1
fi

echo "${EMAIL} -> $(sudo cat "$FILE")"
