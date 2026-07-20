#!/bin/bash
# One-time (idempotent) bootstrap for /var/lib/mail-recovery, the directory
# invite.php writes each new mailbox's recovery email into (one file per
# mailbox address, filename = mailbox, contents = recovery address).
# /var/lib is root:root 755, so www-data (the PHP runtime user) can't create
# this itself -- has to be done once via sudo, same as mail-invites.
#
# Run this before testing the invite flow with the new recovery-email field.
set -euo pipefail

RECOVERY_DIR="/var/lib/mail-recovery"

echo "==> Creating ${RECOVERY_DIR} (owned www-data, mode 700)"
sudo mkdir -p "$RECOVERY_DIR"
sudo chown www-data:www-data "$RECOVERY_DIR"
sudo chmod 700 "$RECOVERY_DIR"

echo "==> Done:"
sudo ls -la "$RECOVERY_DIR"
