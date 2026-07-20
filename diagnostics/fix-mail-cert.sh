#!/bin/bash
# Repoints Dovecot/Postfix TLS from one Let's Encrypt cert to another --
# useful when the wrong cert is being served (e.g. missing the mail
# hostname in its SAN, causing Apple Mail / iOS to hang on "Connecting...").
#
# Usage: ./fix-mail-cert.sh <old-domain> <new-domain>
# Example: ./fix-mail-cert.sh example.com mail.example.com
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <old-domain> <new-domain>"
  exit 1
fi
OLD_DOMAIN="$1"
NEW_DOMAIN="$2"

OLD_CERT="/etc/letsencrypt/live/${OLD_DOMAIN}/fullchain.pem"
OLD_KEY="/etc/letsencrypt/live/${OLD_DOMAIN}/privkey.pem"
NEW_CERT="/etc/letsencrypt/live/${NEW_DOMAIN}/fullchain.pem"
NEW_KEY="/etc/letsencrypt/live/${NEW_DOMAIN}/privkey.pem"

DOVECOT_SSL_CONF="/etc/dovecot/conf.d/10-ssl.conf"
POSTFIX_MAIN_CF="/etc/postfix/main.cf"

echo "==> Backing up configs"
sudo cp "$DOVECOT_SSL_CONF" "${DOVECOT_SSL_CONF}.bak"
sudo cp "$POSTFIX_MAIN_CF" "${POSTFIX_MAIN_CF}.bak"

echo "==> Updating Dovecot TLS cert paths"
sudo sed -i \
  -e "s#${OLD_CERT}#${NEW_CERT}#" \
  -e "s#${OLD_KEY}#${NEW_KEY}#" \
  "$DOVECOT_SSL_CONF"

echo "==> Updating Postfix TLS cert paths"
sudo sed -i \
  -e "s#${OLD_CERT}#${NEW_CERT}#" \
  -e "s#${OLD_KEY}#${NEW_KEY}#" \
  "$POSTFIX_MAIN_CF"

echo "==> Validating configs"
sudo doveconf -n >/dev/null && echo "    dovecot config OK"
sudo postfix check && echo "    postfix config OK"

echo "==> Reloading services"
sudo systemctl reload dovecot
sudo systemctl reload postfix

echo "==> Done. Verifying served cert on port 993:"
echo | openssl s_client -connect localhost:993 -servername "$NEW_DOMAIN" 2>/dev/null \
  | openssl x509 -noout -subject -ext subjectAltName
