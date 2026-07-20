#!/bin/bash
# Backs up real configs into backups/<timestamp>/, gitignored.
set -euo pipefail

OUT="$(dirname "$(dirname "$(readlink -f "$0")")")/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

sudo cat /etc/postfix/main.cf > "$OUT/postfix-main.cf"
sudo cat /etc/postfix/virtual > "$OUT/postfix-virtual"
sudo cat /etc/dovecot/users > "$OUT/dovecot-users"
sudo cat /etc/dovecot/sieve/default.sieve > "$OUT/dovecot-sieve-default.sieve"
sudo cat /etc/fail2ban/jail.local > "$OUT/fail2ban-jail.local" 2>/dev/null || true
sudo cat /etc/nftables.conf > "$OUT/nftables.conf"
sudo cat /etc/postfix/postscreen_access.cidr > "$OUT/postscreen_access.cidr" 2>/dev/null || true
sudo grep -h "mail-add-user\|mail-invite-create\|mail-del-user" /etc/sudoers /etc/sudoers.d/* 2>/dev/null > "$OUT/sudoers-mail-scripts" || true
cat /etc/mailname > "$OUT/mailname"
sudo crontab -l > "$OUT/root-crontab" 2>/dev/null || true

echo "Backed up to $OUT"
