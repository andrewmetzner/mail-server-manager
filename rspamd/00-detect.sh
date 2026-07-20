#!/usr/bin/env bash
# Read-only. Reports how SpamAssassin is currently wired into Postfix/Dovecot
# on THIS box, so the later scripts aren't guessing. Makes no changes.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "===================================================================="
echo " Current mail stack state — $(date)"
echo "===================================================================="

echo
echo "--- OS ---"
grep -E '^(ID|VERSION_CODENAME|PRETTY_NAME)=' /etc/os-release

echo
echo "--- Installed spam/mail packages ---"
dpkg -l 2>/dev/null | grep -iE 'spamassassin|spamass-milter|opendkim|rspamd|redis-server' \
    | awk '{printf "  %-25s %s\n", $2, $3}'

echo
echo "--- Postfix milters (main.cf) ---"
for p in smtpd_milters non_smtpd_milters milter_default_action milter_protocol; do
    printf "  %-24s = %s\n" "$p" "$(postconf -h "$p" 2>/dev/null)"
done

echo
echo "--- master.cf lines mentioning milters/spamass ---"
grep -nE 'milter|spamass' /etc/postfix/master.cf 2>/dev/null || echo "  (none found)"

echo
echo "--- spamass-milter socket ---"
ls -la /var/spool/postfix/spamass/ 2>/dev/null || echo "  not present"

echo
echo "--- Active spam-related services ---"
for svc in spamassassin spamd spamass-milter spamassassin-maintenance.timer opendkim rspamd redis-server; do
    # is-active always prints a word (active/inactive/failed) even on its
    # non-zero "not active" exit code, so no || fallback here — one was
    # firing anyway and appending a bogus extra line to $state.
    state="$(systemctl is-active "$svc" 2>/dev/null)"
    state="${state:-unknown}"
    enabled="$(systemctl is-enabled "$svc" 2>/dev/null || echo "-")"
    printf "  %-32s active=%-14s enabled=%s\n" "$svc" "$state" "$enabled"
done

echo
echo "--- Dovecot sieve wiring ---"
doveconf -n 2>/dev/null | grep -iE 'sieve_before|sieve_after|sieve_plugins|mail_plugins' || echo "  (none found)"
echo
echo "  default.sieve content:"
sed 's/^/    /' /etc/dovecot/sieve/default.sieve 2>/dev/null || echo "    not present"

echo
echo "--- Memory / CPU (rspamd + redis will need headroom) ---"
free -h
nproc --all

echo
echo "===================================================================="
echo " Summary"
echo "===================================================================="
cat <<'EOF'
  * Spam tagging currently happens via spamass-milter, listening on a unix
    socket wired into smtpd_milters, alongside OpenDKIM on 127.0.0.1:8891.
  * Dovecot's default.sieve files mail into Junk purely by checking for
    the header "X-Spam-Flag: YES" — it does not care which product set it.
  * The migration scripts will:
      - add rspamd as a second milter next to OpenDKIM (DKIM is untouched)
      - configure rspamd to emit "X-Spam-Flag: YES/NO" so the existing
        Sieve rule keeps working with no changes
      - remove spamass-milter from smtpd_milters and disable the SpamAssassin
        services (packages are left installed until you're confident, so
        rollback is just re-adding one line to main.cf)
  * This box is memory-constrained (check the free -h output above) —
    redis will be capped at a small maxmemory to avoid adding pressure.

  Review this output, then run the scripts in order: 01, 02, 03, 04, 05, 06.
EOF
