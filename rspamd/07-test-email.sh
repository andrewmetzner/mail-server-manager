#!/usr/bin/env bash
# Sends a real email through Postfix -> OpenDKIM -> rspamd -> Dovecot, to
# prove the whole chain works end to end (not just direct rspamc testing).
# Installs swaks if missing (needs root for that one step).
#
# Usage:
#   bash 07-test-email.sh you@yourdomain.com          # GTUBE spam test, expect reject
#   bash 07-test-email.sh you@yourdomain.com --ham    # benign message, expect delivery

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

if [[ $# -lt 1 ]]; then
    cat <<EOF
Usage: $0 <recipient@yourdomain> [--ham]

  <recipient@yourdomain>   A real mailbox on this server
  --ham                    Send a benign message instead of the GTUBE spam
                            test string (default: spam test, expect reject)
EOF
    exit 1
fi

TO="$1"
MODE="spam"
[[ "${2:-}" == "--ham" ]] && MODE="ham"

if ! command -v swaks >/dev/null; then
    warn "swaks not installed"
    if [[ $EUID -eq 0 ]]; then
        apt-get update -qq && apt-get install -y swaks
    else
        err "Install it first: sudo apt install swaks"
        exit 1
    fi
fi

FROM="rspamd-test@$(hostname -f 2>/dev/null || echo localhost)"
STAMP="$(date +%s)"
SUBJECT="rspamd test ${STAMP}"

before="$(rspamc stat 2>/dev/null | awk -F': ' '/^Messages scanned/{print $2}')"
before="${before:-0}"

log "Sending $MODE test to $TO (from $FROM)"
echo

if [[ "$MODE" == "spam" ]]; then
    BODY='XJS*C4JDBQADN1.NSBN3*2IDNEN*GTUBE-STANDARD-ANTI-UBE-TEST-EMAIL*C.34X'
else
    BODY="This is a benign rspamd delivery test, sent at ${STAMP}."
fi

SWAKS_LOG="$(mktemp)"
trap 'rm -f "$SWAKS_LOG"' EXIT

if swaks --to "$TO" --from "$FROM" --server 127.0.0.1 \
    --header "Subject: ${SUBJECT}" --body "$BODY" 2>&1 | tee "$SWAKS_LOG"; then
    SWAKS_OK=1
else
    SWAKS_OK=0
fi

echo
if [[ "$MODE" == "spam" ]]; then
    if [[ $SWAKS_OK -eq 0 ]] && grep -qE '5[0-9]{2} ' "$SWAKS_LOG"; then
        log "Rejected at SMTP time — correct, this is what should happen to GTUBE."
    else
        warn "Message was NOT rejected — check the transcript above. Either rspamd" \
             "isn't scoring it as spam, or the reject threshold changed."
    fi
else
    if [[ $SWAKS_OK -eq 1 ]]; then
        log "Accepted — check $TO's INBOX for it."
    else
        warn "Benign message was rejected — check the transcript above, something's wrong."
    fi
fi

sleep 2
after="$(rspamc stat 2>/dev/null | awk -F': ' '/^Messages scanned/{print $2}')"
after="${after:-0}"
echo
log "rspamd 'Messages scanned' went from $before to $after (should be +1 if the milter saw it)"

echo
log "Recent journald entries for this test (no rsyslog on this box, so no /var/log/mail.log):"
if [[ $EUID -eq 0 ]]; then
    journalctl --no-pager -q --since "-3 min" -g "$FROM|rspamd|postfix|opendkim" 2>&1 | tail -20 | sed 's/^/  /'
else
    warn "Not running as root — journald hides other users' service logs from you."
    warn "Re-run with sudo to see postfix/rspamd/opendkim log lines here."
fi
