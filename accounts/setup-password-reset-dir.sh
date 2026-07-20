#!/bin/bash
# One-time (idempotent) bootstrap for /var/lib/mail-password-resets, the
# directory forgot-password.php writes reset tokens into (one file per
# token, contents = mailbox email on line 1, expiry unix timestamp on
# line 2). /var/lib is root:root 755, so www-data (the PHP runtime user)
# can't create this itself -- has to be done once via sudo, same as
# mail-invites and mail-recovery.
#
# Run this before testing the forgot-password flow.
set -euo pipefail

RESET_DIR="/var/lib/mail-password-resets"

echo "==> Creating ${RESET_DIR} (owned www-data, mode 700)"
sudo mkdir -p "$RESET_DIR"
sudo chown www-data:www-data "$RESET_DIR"
sudo chmod 700 "$RESET_DIR"

echo "==> Done:"
sudo ls -la "$RESET_DIR"
