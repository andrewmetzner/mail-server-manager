#!/usr/bin/env bash
# Read-only sanity checks after running 01-05. Makes no changes.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "===================================================================="
echo " Service status"
echo "===================================================================="
for svc in redis-server rspamd postfix dovecot; do
    printf "  %-16s %s\n" "$svc" "$(systemctl is-active "$svc" 2>/dev/null)"
done

echo
echo "===================================================================="
echo " Postfix milter chain"
echo "===================================================================="
for p in smtpd_milters milter_protocol milter_default_action; do
    printf "  %-22s = %s\n" "$p" "$(postconf -h "$p" 2>/dev/null)"
done

echo
echo "  Listening milter ports:"
ss -ltnp 2>/dev/null | grep -E ':(8891|11332)' | sed 's/^/    /' || echo "    none found"

echo
echo "===================================================================="
echo " rspamd stats"
echo "===================================================================="
if command -v rspamc >/dev/null; then
    rspamc stat 2>&1 | sed 's/^/  /'
else
    echo "  rspamc not installed"
fi

echo
echo "===================================================================="
echo " GTUBE test (standard spam-test string, should score as spam/reject)"
echo "===================================================================="
if command -v rspamc >/dev/null; then
    GTUBE='XJS*C4JDBQADN1.NSBN3*2IDNEN*GTUBE-STANDARD-ANTI-UBE-TEST-EMAIL*C.34X'
    printf 'Subject: GTUBE test\n\n%s\n' "$GTUBE" | rspamc symbols 2>&1 | sed 's/^/  /'
else
    echo "  rspamc not installed, skipping"
fi

echo
echo "===================================================================="
echo " Recent rspamd/postfix activity (journald — no rsyslog/mail.log on this box)"
echo "===================================================================="
if [[ $EUID -eq 0 ]]; then
    journalctl --no-pager -q --since "-10 min" -g "rspamd|postfix|opendkim" 2>&1 | tail -15 | sed 's/^/  /'
    [[ -z "$(journalctl --no-pager -q --since "-10 min" -g "rspamd|postfix|opendkim" 2>&1)" ]] && echo "  (no matches yet — send a test email, e.g. bash 07-test-email.sh)"
else
    echo "  Not running as root — journald hides other users' service logs. Re-run with sudo."
fi

echo
echo "===================================================================="
echo " Memory"
echo "===================================================================="
free -h

echo
echo "===================================================================="
echo " Manual end-to-end test"
echo "===================================================================="
cat <<'EOF'
  Send yourself a real test email and check the headers for X-Spamd-Result /
  X-Spam-Status, e.g. with swaks (apt install swaks):

    swaks --to you@yourdomain.com --from test@example.com \
      --server 127.0.0.1 --data - <<'MSG'
    Subject: rspamd test

    XJS*C4JDBQADN1.NSBN3*2IDNEN*GTUBE-STANDARD-ANTI-UBE-TEST-EMAIL*C.34X
    MSG

  Then check the message landed in Junk (proves the Sieve rule matched),
  and check /var/log/dovecot-rspamd-learn.log after dragging a message
  into/out of Junk in your mail client (proves autolearn is firing).
EOF
