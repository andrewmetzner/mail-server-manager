#!/bin/bash
# Root-owned script. NOT admin-run directly -- deployed to
# /usr/local/bin/mail-reset-password.sh and called via passwordless sudo
# from reset-password.php (the self-service forgot-password flow), the
# same way mail-add-user.sh is called from invite.php.
#
# Mirrors reset-mail-password.sh's safe backup/ACL-preserving update so
# rewriting /etc/dovecot/users never drops the www-data read ACL that
# invite.php and forgot-password.php depend on for availability/lookup
# checks.
#
# Usage: mail-reset-password.sh user@domain.com '<hash>'
#
# Deploy:
#   sudo cp accounts/mail-reset-password.sh /usr/local/bin/mail-reset-password.sh
#   sudo chown root:root /usr/local/bin/mail-reset-password.sh
#   sudo chmod 700 /usr/local/bin/mail-reset-password.sh
# and grant www-data NOPASSWD sudo for it -- see examples/sudoers-mail-scripts.
set -euo pipefail

USERS_FILE="/etc/dovecot/users"

if [ $# -ne 2 ]; then
    echo "Usage: $0 user@domain.com '<hash>'" >&2
    exit 1
fi
EMAIL="$1"
HASH="$2"

if ! grep -q "^${EMAIL}:" "$USERS_FILE"; then
    echo "No such user: ${EMAIL}" >&2
    exit 1
fi

ACL_SNAPSHOT="$(mktemp)"
getfacl "$USERS_FILE" > "$ACL_SNAPSHOT"

awk -F: -v user="$EMAIL" -v hash="$HASH" 'BEGIN{OFS=":"} $1==user { $2=hash } { print }' "$USERS_FILE" > "${USERS_FILE}.tmp"
mv "${USERS_FILE}.tmp" "$USERS_FILE"
chown root:vmail "$USERS_FILE"
chmod 640 "$USERS_FILE"

setfacl --set-file="$ACL_SNAPSHOT" "$USERS_FILE"
rm -f "$ACL_SNAPSHOT"

doveadm reload
