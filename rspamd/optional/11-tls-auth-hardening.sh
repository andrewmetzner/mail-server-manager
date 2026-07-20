#!/usr/bin/env bash
# OPTIONAL — real behavior change, read before running.
#
# 1. Dovecot: disable_plaintext_auth is currently "no". This flips it to
#    "yes", meaning IMAP/POP3 clients can no longer send plaintext
#    credentials over an unencrypted connection. This is safe for clients
#    using the SSL ports (993/995) or STARTTLS, which is standard in any
#    mail client from the last decade — but if anything on your network is
#    configured for plain port 143/110 with no encryption, it will break
#    until reconfigured. Submission (587) already forces TLS before AUTH
#    (smtpd_tls_security_level=encrypt), so this mainly affects Dovecot's
#    own IMAP/POP3 auth, not Postfix.
#
# 2. Postfix: smtpd_tls_mandatory_protocols / smtpd_tls_protocols are
#    currently ">=TLSv1" (allows TLS 1.0/1.1). This raises the floor to
#    TLS 1.2, matching current best practice. Only an issue if something
#    genuinely ancient connects to your MX with TLS 1.0/1.1 — unlikely.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root

echo "This will:"
echo "  - set disable_plaintext_auth = yes in Dovecot"
echo "  - raise Postfix's TLS floor to TLSv1.2 (smtpd_tls_{mandatory_,}protocols)"
confirm "Proceed?" || exit 0

backup_file /etc/dovecot/conf.d/10-auth.conf
if grep -q '^disable_plaintext_auth' /etc/dovecot/conf.d/10-auth.conf 2>/dev/null; then
    sed -i 's/^disable_plaintext_auth.*/disable_plaintext_auth = yes/' /etc/dovecot/conf.d/10-auth.conf
else
    echo 'disable_plaintext_auth = yes' >> /etc/dovecot/conf.d/10-auth.conf
fi
log "Set disable_plaintext_auth = yes"

backup_file /etc/postfix/main.cf
postconf -e "smtpd_tls_mandatory_protocols = >=TLSv1.2"
postconf -e "smtpd_tls_protocols = >=TLSv1.2"
log "Raised Postfix TLS floor to TLSv1.2"

log "Validating configs"
if ! doveconf -n >/dev/null; then
    err "doveconf failed — check ${BACKUP_ROOT}/ for the pre-change 10-auth.conf"
    exit 1
fi
if ! postfix check; then
    err "postfix check failed — check ${BACKUP_ROOT}/ for the pre-change main.cf"
    exit 1
fi

systemctl reload postfix
systemctl restart dovecot

log "Done. Test IMAP/SMTP auth from your actual mail clients before walking away."
