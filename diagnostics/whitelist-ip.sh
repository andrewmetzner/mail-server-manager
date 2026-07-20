#!/bin/bash
# Permanently whitelists an IP in fail2ban (dovecot, postfix, sasl, sshd jails)
# so it can never be banned, and unbans it immediately if currently banned.
#
# Usage: ./whitelist-ip.sh <ip-address>
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <ip-address>"
  exit 1
fi
TRUSTED_IP="$1"
JAIL_LOCAL="/etc/fail2ban/jail.local"

if [ -f "$JAIL_LOCAL" ] && sudo grep -q "^ignoreip" "$JAIL_LOCAL"; then
  if sudo grep "^ignoreip" "$JAIL_LOCAL" | grep -qF "$TRUSTED_IP"; then
    echo "==> ${TRUSTED_IP} is already whitelisted in ${JAIL_LOCAL}"
  else
    echo "==> Appending ${TRUSTED_IP} to existing ignoreip line in ${JAIL_LOCAL}"
    sudo sed -i "/^ignoreip/ s/\$/ ${TRUSTED_IP}/" "$JAIL_LOCAL"
  fi
else
  echo "==> Creating ${JAIL_LOCAL} with ignoreip"
  sudo tee -a "$JAIL_LOCAL" > /dev/null <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 ${TRUSTED_IP}
EOF
fi

echo "==> Unbanning ${TRUSTED_IP} from all jails (in case it's currently banned)"
for jail in dovecot postfix sasl sshd; do
  sudo fail2ban-client set "$jail" unbanip "$TRUSTED_IP" 2>/dev/null || true
done

echo "==> Restarting fail2ban to apply ignoreip"
sudo systemctl restart fail2ban

echo "==> Verifying:"
sudo fail2ban-client get dovecot ignoreip
