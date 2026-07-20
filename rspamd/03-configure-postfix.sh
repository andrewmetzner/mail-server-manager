#!/usr/bin/env bash
# Rewires Postfix's milter chain: adds rspamd (127.0.0.1:11332) next to your
# existing OpenDKIM milter (127.0.0.1:8891), and removes the spamass-milter
# unix socket. DKIM is untouched — order stays "DKIM first, then rspamd" so
# rspamd sees any Authentication-Results DKIM already added.
#
# Also fixes a pre-existing bug in main.cf: line 69 currently reads
#   milter_protocol = 2smtpd_helo_required = yes
# i.e. two directives mashed onto one line with no newline between them.
# That means smtpd_helo_required=yes has *never actually been active* even
# though it's clearly what was intended. This script splits it into two
# correct lines: milter_protocol = 6 (the value rspamd's docs expect) and
# smtpd_helo_required = yes (now genuinely enabled). This is unrelated to
# rspamd — flagging it because it's a real behavior change: Postfix will
# start rejecting senders that skip HELO/EHLO, which it silently wasn't
# doing before. Pass --skip-helo-fix to leave that part alone.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root

FIX_HELO=1
if [[ "${1:-}" == "--skip-helo-fix" ]]; then
    FIX_HELO=0
    warn "Skipping smtpd_helo_required fix (--skip-helo-fix)"
fi

if ! ss -ltn 2>/dev/null | grep -q ':11332'; then
    err "Nothing listening on 127.0.0.1:11332 — run 02-configure-rspamd.sh first."
    exit 1
fi

backup_file /etc/postfix/main.cf
backup_file /etc/postfix/master.cf

log "Current smtpd_milters: $(postconf -h smtpd_milters)"

log "Setting smtpd_milters to OpenDKIM + rspamd (dropping spamass-milter socket)"
postconf -e "smtpd_milters = inet:127.0.0.1:8891 inet:127.0.0.1:11332"

log "Setting milter_protocol = 6, milter_default_action = accept"
postconf -e "milter_protocol = 6"
postconf -e "milter_default_action = accept"

if [[ $FIX_HELO -eq 1 ]]; then
    log "Fixing corrupted line: separating out smtpd_helo_required = yes"
    postconf -e "smtpd_helo_required = yes"
fi

log "Verifying no leftover spamass-milter references"
grep -n 'spamass' /etc/postfix/main.cf /etc/postfix/master.cf && \
    warn "Found leftover 'spamass' references above — check manually" || \
    log "None found"

log "Checking config syntax"
if ! postfix check; then
    err "postfix check FAILED. main.cf/master.cf backups are under ${BACKUP_ROOT}/ — restore with:"
    err "  cp ${BACKUP_ROOT}/03-configure-postfix-${TS}/etc/postfix/main.cf /etc/postfix/main.cf"
    exit 1
fi

log "New smtpd_milters: $(postconf -h smtpd_milters)"
log "New milter_protocol: $(postconf -h milter_protocol)"
log "New smtpd_helo_required: $(postconf -h smtpd_helo_required)"

log "Reloading postfix (graceful, no dropped connections)"
systemctl reload postfix

echo
log "Done. Postfix now sends mail through OpenDKIM -> rspamd."
log "spamass-milter is still running as a service but nothing calls it anymore."
log "Next: run 04-disable-spamassassin.sh, then 05-dovecot-autolearn.sh"
