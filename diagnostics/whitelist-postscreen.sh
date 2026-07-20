#!/bin/bash
# Adds a CIDR range to postscreen's access list so matching IPs skip ALL
# postscreen tests (DNSBL scoring, pregreet, pipelining, bare-newline) and
# go straight to smtpd for a normal SMTP dialogue.
#
# Use this for large legitimate senders whose outbound IP pool is so big
# and fast-rotating that they never survive postscreen's built-in
# "unknown client" behavior: the FIRST time postscreen sees a new IP, it
# always issues one 450 4.3.2 temp-fail (by design, to filter spambots
# that don't retry) and only whitelists that IP for next time. A sender
# like iCloud, which uses a different outbound IP on nearly every retry,
# can get stuck retrying forever without ever landing on a cached IP.
# See README.org, "Inbound mail not arriving".
#
# Usage: ./whitelist-postscreen.sh <cidr> ["description"]
# Example: ./whitelist-postscreen.sh 57.103.64.0/18 "iCloud outbound, per icloud.com SPF record, 2026-07-08"
set -euo pipefail

ACCESS_FILE="/etc/postfix/postscreen_access.cidr"
MAIN_CF="/etc/postfix/main.cf"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <cidr> [\"description\"]"
  exit 1
fi
CIDR="$1"
DESC="${2:-}"

echo "==> Backing up ${MAIN_CF}"
sudo cp "$MAIN_CF" "${MAIN_CF}.bak-$(date +%Y%m%d%H%M%S)"

if sudo test -f "$ACCESS_FILE" && sudo grep -qF "$CIDR" "$ACCESS_FILE"; then
  echo "==> ${CIDR} is already whitelisted in ${ACCESS_FILE}"
else
  echo "==> Adding ${CIDR} to ${ACCESS_FILE}"
  { [ -n "$DESC" ] && echo "# ${DESC}"; echo "${CIDR}  permit"; } | sudo tee -a "$ACCESS_FILE" > /dev/null
fi

if ! sudo grep -q "^postscreen_access_list" "$MAIN_CF"; then
  echo "==> Enabling postscreen_access_list in ${MAIN_CF} (preserves the built-in permit_mynetworks default)"
  printf '\npostscreen_access_list = permit_mynetworks, cidr:%s\n' "$ACCESS_FILE" | sudo tee -a "$MAIN_CF" > /dev/null
fi

echo "==> Validating config"
sudo postfix check && echo "    postfix config OK"

echo "==> Reloading postfix"
sudo systemctl reload postfix

echo "==> Done. ${CIDR} now skips postscreen's DNSBL/pregreet/pipelining tests entirely."
