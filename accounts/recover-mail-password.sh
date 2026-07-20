#!/bin/bash
# Generates a new random password for an existing mailbox and emails it to
# a chosen recovery address (the account holder is, by definition, locked
# out of retrieving it from their own inbox). Does the same safe
# backup/ACL-preserving update as reset-mail-password.sh, but with a
# generated password instead of an interactive prompt.
#
# Sending domain comes from ../domainlist (gitignored -- copy domainlist.example first).
#
# Usage: ./recover-mail-password.sh user@domain.com send-to@example.com
set -euo pipefail

USERS_FILE="/etc/dovecot/users"

DOMAIN_FILE="$(dirname "$(dirname "$(readlink -f "$0")")")/domainlist"
[ -f "$DOMAIN_FILE" ] || { echo "Missing $DOMAIN_FILE -- copy domainlist.example to domainlist and set your domain." >&2; exit 1; }
DOMAIN="$(head -n1 "$DOMAIN_FILE")"

if [ $# -ne 2 ]; then
  echo "Usage: $0 user@domain.com send-to@example.com"
  exit 1
fi
USER_ACCOUNT="$1"
SEND_TO="$2"

echo "==> Checking ${USER_ACCOUNT} exists in ${USERS_FILE}"
sudo grep -q "^${USER_ACCOUNT}:" "$USERS_FILE" || { echo "No existing entry found for ${USER_ACCOUNT} -- aborting."; exit 1; }

NEW_PASSWORD="$(openssl rand -base64 18 | tr -d '/+=')"
# Piped via stdin (not -p) so the plaintext never appears in `ps` output.
NEW_HASH="$(printf '%s\n%s\n' "$NEW_PASSWORD" "$NEW_PASSWORD" | doveadm pw -s SHA512-CRYPT 2>/dev/null)"

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

echo "==> Reloading dovecot"
sudo systemctl reload dovecot

echo "==> Emailing new password to ${SEND_TO}"
mail -s "Password reset for ${USER_ACCOUNT}" \
     -a "From: $(whoami) <$(whoami)@${DOMAIN}>" \
     "$SEND_TO" <<EOF
The password for ${USER_ACCOUNT} has been reset.

New password: ${NEW_PASSWORD}

Please log in and change it as soon as possible.

-- $(whoami)
EOF

echo "==> Done."
