#!/bin/bash
# Creates an invite token (via mail-invite-create.sh) and emails the signup
# link to the given address. The token lives in /var/lib/mail-invites
# (owned by www-data) and is redeemed by invite.php on the web side, which
# calls mail-add-user.sh. Tokens expire after 48h (see root crontab).
#
# Domain comes from ../domainlist (gitignored -- copy domainlist.example first).
#
# Usage: ./invite-user.sh <name> <send-to-email>
# Example: ./invite-user.sh june june@example.com
set -euo pipefail

DOMAIN_FILE="$(dirname "$(dirname "$(readlink -f "$0")")")/domainlist"
[ -f "$DOMAIN_FILE" ] || { echo "Missing $DOMAIN_FILE -- copy domainlist.example to domainlist and set your domain." >&2; exit 1; }
DOMAIN="$(head -n1 "$DOMAIN_FILE")"

if [ $# -ne 2 ]; then
  echo "Usage: $0 <name> <send-to-email>"
  exit 1
fi
NAME="$1"
SEND_TO="$2"

echo "==> Creating invite for ${NAME}@${DOMAIN}"
CREATE_OUTPUT="$(/usr/local/bin/mail-invite-create.sh "$NAME")"
echo "$CREATE_OUTPUT"

LINK="$(echo "$CREATE_OUTPUT" | sed -n 's/^Link: //p')"
if [ -z "$LINK" ]; then
  echo "Could not parse invite link from the output above -- not sending email." >&2
  exit 1
fi

echo "==> Emailing invite link to ${SEND_TO}"
mail -s "You're invited to ${DOMAIN} mail" \
     -a "From: $(whoami) <$(whoami)@${DOMAIN}>" \
     "$SEND_TO" <<EOF
You've been invited to set up a mailbox on ${DOMAIN}.

Click the link below to finish setup (valid for 48 hours):

${LINK}

-- $(whoami)
EOF

echo "==> Sent to ${SEND_TO}."
