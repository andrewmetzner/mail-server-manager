#!/bin/bash
# Directly adds a mailbox, bypassing the invite flow (e.g. accounts you
# don't want to send an invite link for). Wraps mail-add-user.sh, the same
# script the web invite-redemption flow calls.
#
# Usage: ./add-mail-user.sh user@example.com
set -euo pipefail

USERS_FILE="/etc/dovecot/users"

if [ $# -ne 1 ]; then
  echo "Usage: $0 user@domain.com"
  exit 1
fi
EMAIL="$1"

echo "==> Checking ${EMAIL} doesn't already exist"
if sudo grep -q "^${EMAIL}:" "$USERS_FILE"; then
  echo "${EMAIL} already exists in ${USERS_FILE} -- aborting. Use reset-mail-password.sh to change its password instead." >&2
  exit 1
fi

echo "==> Enter the password for ${EMAIL} when prompted (typed twice, hidden):"
HASH="$(doveadm pw -s SHA512-CRYPT 2>/dev/null)"

echo "==> Creating mailbox"
sudo /usr/local/bin/mail-add-user.sh "$EMAIL" "$HASH"

echo "==> Done. New line:"
sudo grep "^${EMAIL}:" "$USERS_FILE"
