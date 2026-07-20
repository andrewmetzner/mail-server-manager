#!/usr/bin/env bash
# Wires Dovecot IMAPSieve so that:
#   - moving a message INTO Junk    -> rspamc learn_spam
#   - moving a message OUT of Junk  -> rspamc learn_ham
# Also updates default.sieve to route on rspamd's own headers instead of
# SpamAssassin's X-Spam-Flag (rspamd always adds X-Spamd-Result by default;
# extended_spam_headers from 02-configure-rspamd.sh also adds X-Spam-Status
# for belt-and-suspenders compatibility).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root

if ! command -v rspamc >/dev/null; then
    err "rspamc not found — run 01-install-rspamd.sh first."
    exit 1
fi

SIEVE_DIR=/etc/dovecot/sieve
BIN_DIR=${SIEVE_DIR}/scripts

log "Updating default.sieve to match on rspamd's headers instead of X-Spam-Flag"
backup_file "${SIEVE_DIR}/default.sieve"
cat > "${SIEVE_DIR}/default.sieve" <<'EOF'
require ["fileinto", "mailbox"];

# Mail tagged as spam by rspamd goes straight to Junk. rspamd always adds
# X-Spamd-Result ("default: True/False [...]"); X-Spam-Status is also present
# because extended_spam_headers=true is set in rspamd's milter_headers.conf.
if anyof (
    header :contains "X-Spamd-Result" "True",
    header :contains "X-Spam-Status" "Yes"
) {
    fileinto :create "Junk";
    stop;
}

# If it's a DeltaChat message, move it to the DeltaChat folder.
# The :create tag ensures the folder is made if it doesn't exist yet.
if header :contains "Chat-Version" "1.0" {
    fileinto :create "DeltaChat";
    stop;
}
EOF
chown vmail:vmail "${SIEVE_DIR}/default.sieve"

log "Creating pipe-program directory for extprograms (must NOT be writable by the mail user)"
mkdir -p "$BIN_DIR"
chown root:root "$BIN_DIR"
chmod 755 "$BIN_DIR"

log "Writing rspamc learn wrapper scripts"
cat > "${BIN_DIR}/rspamd-learn-spam.sh" <<'EOF'
#!/bin/sh
# Invoked by Dovecot IMAPSieve (via sieve_extprograms) when a message is
# copied/moved into Junk. Message comes in on stdin.
exec rspamc -h 127.0.0.1:11334 learn_spam >>/var/log/dovecot-rspamd-learn.log 2>&1
EOF

cat > "${BIN_DIR}/rspamd-learn-ham.sh" <<'EOF'
#!/bin/sh
# Invoked by Dovecot IMAPSieve when a message is copied/moved out of Junk.
exec rspamc -h 127.0.0.1:11334 learn_ham >>/var/log/dovecot-rspamd-learn.log 2>&1
EOF

chown root:root "${BIN_DIR}"/*.sh
chmod 755 "${BIN_DIR}"/*.sh

touch /var/log/dovecot-rspamd-learn.log
chown vmail:vmail /var/log/dovecot-rspamd-learn.log

log "Writing learn-spam.sieve / learn-ham.sieve"
cat > "${SIEVE_DIR}/learn-spam.sieve" <<'EOF'
require ["vnd.dovecot.pipe", "copy"];
pipe :copy "rspamd-learn-spam.sh";
EOF

cat > "${SIEVE_DIR}/learn-ham.sieve" <<'EOF'
require ["vnd.dovecot.pipe", "copy"];
pipe :copy "rspamd-learn-ham.sh";
EOF

chown vmail:vmail "${SIEVE_DIR}/learn-spam.sieve" "${SIEVE_DIR}/learn-ham.sieve"

log "Adding Dovecot IMAPSieve config (91-rspamd-training.conf)"
backup_file /etc/dovecot/conf.d/91-rspamd-training.conf
cat > /etc/dovecot/conf.d/91-rspamd-training.conf <<EOF
# Added by rspamd-migration/05-dovecot-autolearn.sh
plugin {
  sieve_plugins = sieve_imapsieve sieve_extprograms

  sieve_extprograms_bin_dir = ${BIN_DIR}
  sieve_global_extensions = +vnd.dovecot.pipe

  imapsieve_mailbox1_name = Junk
  imapsieve_mailbox1_causes = COPY
  imapsieve_mailbox1_before = file:${SIEVE_DIR}/learn-spam.sieve

  imapsieve_mailbox2_name = *
  imapsieve_mailbox2_from = Junk
  imapsieve_mailbox2_causes = COPY
  imapsieve_mailbox2_before = file:${SIEVE_DIR}/learn-ham.sieve
}

protocol imap {
  mail_plugins = \$mail_plugins imap_sieve
}
EOF

log "Validating Dovecot config"
if ! doveconf -n >/dev/null; then
    err "doveconf failed to parse the new config. Backups are under ${BACKUP_ROOT}/"
    exit 1
fi

log "Restarting dovecot"
systemctl restart dovecot
sleep 1
systemctl --no-pager status dovecot | head -10

echo
log "Done. Moving mail into/out of Junk in your IMAP client will now train rspamd."
log "Watch /var/log/dovecot-rspamd-learn.log for learn activity."
log "Next: run 06-verify.sh"
