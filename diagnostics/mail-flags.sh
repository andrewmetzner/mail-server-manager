#!/bin/bash
# Shows fail2ban-banned/recently-banned IPs, plus postfix/dovecot log lines
# that look like a rejected, held, discarded, or spam-filed message --
# for troubleshooting inbound mail that never arrives. Useful when the
# sender is on a shared relay (e.g. iCloud), where one banned IP or a
# spam-score hit can silently swallow mail from many senders at once.
#
# Usage: ./mail-flags.sh [search-term] [hours-back]
#   search-term defaults to "icloud" -- pass "" to see everything unfiltered.
#   hours-back defaults to 24.
set -uo pipefail

TERM="${1-icloud}"
HOURS="${2:-24}"

echo "==> fail2ban: currently banned IPs (all jails)"
for jail in dovecot postfix sasl sshd; do
  echo "--- $jail ---"
  sudo fail2ban-client status "$jail" 2>&1 | grep -i "banned"
done

echo
echo "==> /var/log/fail2ban.log: recent ban/unban activity"
if [ -n "$TERM" ]; then
  sudo grep -iE "ban|unban" /var/log/fail2ban.log | grep -i "$TERM"
else
  sudo grep -iE "ban|unban" /var/log/fail2ban.log | tail -100
fi

echo
echo "==> postfix: reject/bounce/hold/discard activity, last ${HOURS}h"
echo "    (not filtered by search-term: postscreen's pre-greet tests reject before"
echo "    a MAIL FROM is ever parsed, so those lines only ever show the client IP)"
sudo journalctl -u postfix@- --no-pager --since "${HOURS} hours ago" 2>&1 | grep -iE "reject|bounce|hold|discard|NOQUEUE|DNSBL|4\.3\.2|Service currently unavailable|policyd-spf|connect to|spawn"

echo
echo "==> dovecot/sieve: mail auto-filed to Junk (delivered, not rejected -- easy to mistake for 'never arrived'), last ${HOURS}h"
echo "    (not filtered by search-term: sieve delivery logs don't include the sender address, just recipient/mailbox)"
sudo journalctl -u dovecot --no-pager --since "${HOURS} hours ago" 2>&1 | grep -iE "sieve|fileinto|junk"

echo
echo "==> policyd-spf health check (spawned per-connection by postfix master, not its own systemd unit)"
echo "--- private socket dir ---"
sudo ls -la /var/spool/postfix/private/ 2>&1 | grep -i spf
echo "--- pid file (mtime is a rough 'last activity' signal) ---"
sudo ls -la /var/spool/postfix/pid/unix.policyd-spf 2>&1
echo "--- any policyd-spf / connect-refused warnings across the full retained journal (not just ${HOURS}h) ---"
sudo journalctl -u postfix@- --no-pager 2>&1 | grep -iE "policyd-spf|connect to private/policyd|spawn.*policyd" | tail -50
