#!/bin/bash
# Deploys the web-facing PHP/HTML pages in this folder to the live mail
# docroot. Needs sudo -- /var/www is root-owned 755 and the docroot itself
# is www-data:www-data, so you can't write into it directly.
#
# Lints every .php file with `php -l` first and aborts the whole deploy if
# any fail. Backs up whatever's currently live (timestamped) before
# overwriting each file, so a bad deploy can be rolled back by hand.
#
# Domain comes from ../domainlist (gitignored -- copy domainlist.example first).
#
# Usage: ./deploy-web-pages.sh
set -euo pipefail

SRC_DIR="$(dirname "$(readlink -f "$0")")"
DOMAIN_FILE="$(dirname "$SRC_DIR")/domainlist"
[ -f "$DOMAIN_FILE" ] || { echo "Missing $DOMAIN_FILE -- copy domainlist.example to domainlist and set your domain." >&2; exit 1; }
DOMAIN="$(head -n1 "$DOMAIN_FILE")"

WEBROOT="/var/www/mail.${DOMAIN}/html"
FILES=(invite.php forgot-password.php reset-password.php index.html)

echo "==> Checking PHP syntax before deploying anything"
for f in "${FILES[@]}"; do
  case "$f" in
    *.php)
      SRC="${SRC_DIR}/${f}"
      [ -f "$SRC" ] || continue
      php -l "$SRC" || { echo "Aborting -- ${f} has a syntax error." >&2; exit 1; }
      ;;
  esac
done

echo "==> Deploying to ${WEBROOT}"
for f in "${FILES[@]}"; do
  SRC="${SRC_DIR}/${f}"
  DEST="${WEBROOT}/${f}"

  if [ ! -f "$SRC" ]; then
    echo "Skipping ${f} -- not found in ${SRC_DIR}" >&2
    continue
  fi

  if sudo test -f "$DEST"; then
    BACKUP="${DEST}.bak-$(date +%Y%m%d%H%M%S)"
    sudo cp "$DEST" "$BACKUP"
    echo "==> Backed up existing ${f} -> $(basename "$BACKUP")"
  fi

  sudo cp "$SRC" "$DEST"
  sudo chown www-data:www-data "$DEST"
  sudo chmod 664 "$DEST"
  echo "==> Deployed ${f}"
done

echo "==> Done. Live files:"
sudo ls -la "$WEBROOT"
