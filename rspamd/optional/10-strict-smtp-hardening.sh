#!/usr/bin/env bash
# OPTIONAL. Most of "reject obvious spam at the SMTP stage" is already in
# place on this box:
#   - postscreen already does DNSBL checks (zen.spamhaus.org, barracuda,
#     spamcop, sorbs) before Postfix even accepts the connection — adding
#     reject_rbl_client again in smtpd_recipient_restrictions would just
#     duplicate that check for no benefit.
#   - smtpd_sender_restrictions already rejects non-FQDN / unknown-domain
#     senders and checks dbl.spamhaus.org.
#   - smtpd_recipient_restrictions already rejects unauth destinations,
#     non-FQDN recipients, unknown recipient domains, and runs policyd-spf.
#
# The one genuine gap: smtpd_helo_restrictions checks for an invalid HELO
# hostname but not a non-FQDN one. This adds that single check.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root

current="$(postconf -h smtpd_helo_restrictions)"
echo "Current smtpd_helo_restrictions:"
echo "  $current"

if [[ "$current" == *reject_non_fqdn_helo_hostname* ]]; then
    log "reject_non_fqdn_helo_hostname already present — nothing to do."
    exit 0
fi

backup_file /etc/postfix/main.cf

new="permit_mynetworks, permit_sasl_authenticated, reject_invalid_helo_hostname, reject_non_fqdn_helo_hostname, permit"
log "Setting smtpd_helo_restrictions = $new"
postconf -e "smtpd_helo_restrictions = $new"

if ! postfix check; then
    err "postfix check failed, backup is in ${BACKUP_ROOT}/"
    exit 1
fi

systemctl reload postfix
log "Done."
