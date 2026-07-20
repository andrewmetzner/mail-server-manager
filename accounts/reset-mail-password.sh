#!/bin/bash
# General-purpose password reset for any mailbox in /etc/dovecot/users.
# Usage: ./reset-mail-password.sh user@domain.com
#
# Prompts for the new password directly (via doveadm pw), so the plaintext
# never has to be typed/pasted anywhere else. Preserves any extra
# colon-separated fields on the user's line (uid/gid/home/quota) and the
# file's ACL (e.g. the www-data entry used by the web admin panel).
set -euo pipefail

USERS_FILE="/etc/dovecot/users"

if [ $# -ne 1 ]; then
  echo "Usage: $0 user@domain.com"
  exit 1
fi
USER_ACCOUNT="$1"

echo "==> Checking ${USER_ACCOUNT} exists in ${USERS_FILE}"
sudo grep -q "^${USER_ACCOUNT}:" "$USERS_FILE" || { echo "No existing entry found for ${USER_ACCOUNT} -- aborting."; exit 1; }
echo "==> Current line:"
sudo grep "^${USER_ACCOUNT}:" "$USERS_FILE"

echo
echo "==> Enter the new password for ${USER_ACCOUNT} when prompted (typed twice, hidden):"
NEW_HASH="$(doveadm pw -s SHA512-CRYPT)"

echo "==> Backing up ${USERS_FILE} (including ACL)"
BACKUP="${USERS_FILE}.bak-$(date +%Y%m%d%H%M%S)"
sudo cp "$USERS_FILE" "$BACKUP"
ACL_SNAPSHOT="/tmp/dovecot-users.acl.$$"
sudo getfacl "$USERS_FILE" > "$ACL_SNAPSHOT"

echo "==> Replacing password hash, preserving any extra fields"
sudo awk -F: -v user="$USER_ACCOUNT" -v hash="$NEW_HASH" 'BEGIN{OFS=":"} $1==user { $2=hash; print; next } { print }' "$USERS_FILE" | sudo tee "${USERS_FILE}.tmp" > /dev/null
sudo mv "${USERS_FILE}.tmp" "$USERS_FILE"
sudo chown root:vmail "$USERS_FILE"
sudo chmod 640 "$USERS_FILE"

echo "==> Restoring original ACL (incl. www-data access)"
sudo setfacl --set-file="$ACL_SNAPSHOT" "$USERS_FILE"
rm -f "$ACL_SNAPSHOT"

echo "==> New line for ${USER_ACCOUNT}:"
sudo grep "^${USER_ACCOUNT}:" "$USERS_FILE"

echo "==> Reloading dovecot"
sudo systemctl reload dovecot

echo "==> Done. Update the saved password in any mail client using ${USER_ACCOUNT}."
