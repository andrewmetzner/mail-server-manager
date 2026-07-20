#!/usr/bin/env bash
# Stops and disables SpamAssassin services now that Postfix no longer routes
# mail to spamass-milter (run 03-configure-postfix.sh first). Packages are
# left installed so rollback is cheap — this only stops the daemons.
# Pass --purge to also apt remove the packages once you're confident.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root

if postconf -h smtpd_milters 2>/dev/null | grep -q spamass; then
    err "smtpd_milters still references spamass — run 03-configure-postfix.sh first."
    exit 1
fi

for svc in spamass-milter spamd spamassassin-maintenance.timer; do
    if systemctl list-unit-files 2>/dev/null | grep -q "^${svc}"; then
        log "Stopping + disabling $svc"
        systemctl disable --now "$svc" 2>&1 || warn "Couldn't stop/disable $svc (may already be off)"
    fi
done

echo
free -h

if [[ "${1:-}" == "--purge" ]]; then
    log "Purging spamassassin packages"
    apt-get purge -y spamassassin spamass-milter spamc spamd sa-compile
    apt-get autoremove -y
else
    log "Packages left installed. Re-run with --purge once you're confident, to reclaim disk/mem."
fi

echo
log "Done. SpamAssassin is stopped. rspamd is now the only spam filter in the chain."
log "Next: run 05-dovecot-autolearn.sh, then 06-verify.sh"
