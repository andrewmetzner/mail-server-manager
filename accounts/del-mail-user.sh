#!/bin/bash
# Deletes a mailbox: removes it from Dovecot, deletes its Maildir, and
# scrubs it from the Hall of Fame page. Wraps mail-del-user.sh.
# Irreversible (Maildir is rm -rf'd) -- confirms before running.
#
# Domain comes from ../domainlist (gitignored -- copy domainlist.example first).
#
# Usage: ./del-mail-user.sh username
# (username only, no @domain -- e.g. 'alice' not 'alice@example.com')
set -euo pipefail

DOMAIN_FILE="$(dirname "$(dirname "$(readlink -f "$0")")")/domainlist"
[ -f "$DOMAIN_FILE" ] || { echo "Missing $DOMAIN_FILE -- copy domainlist.example to domainlist and set your domain." >&2; exit 1; }
DOMAIN="$(head -n1 "$DOMAIN_FILE")"

if [ $# -ne 1 ]; then
  echo "Usage: $0 username"
  exit 1
fi
USER="$1"
EMAIL="${USER}@${DOMAIN}"

echo "This will permanently delete ${EMAIL} and its Maildir. This cannot be undone."
read -r -p "Type the username again to confirm: " CONFIRM
if [ "$CONFIRM" != "$USER" ]; then
  echo "Confirmation did not match -- aborting."
  exit 1
fi

/usr/local/bin/mail-del-user.sh "$USER"
