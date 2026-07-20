#!/usr/bin/env bash
# Configures rspamd: redis backend (bayes + greylisting), milter proxy worker
# on 127.0.0.1:11332, and native spam-result headers. Does NOT touch Postfix —
# that's 03-configure-postfix.sh. Safe to re-run.
#
# NOTE ON DKIM: your existing OpenDKIM milter (127.0.0.1:8891) is left alone.
# rspamd can do DKIM too, but re-plumbing signing keys is a separate, riskier
# project — out of scope here. This only replaces the spam-scoring job that
# spamass-milter was doing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root

if ! command -v rspamd >/dev/null; then
    err "rspamd not installed. Run 01-install-rspamd.sh first."
    exit 1
fi

mkdir -p /etc/rspamd/local.d

log "Configuring redis backend (used by bayes + greylisting)"
cat > /etc/rspamd/local.d/redis.conf <<'EOF'
# Added by rspamd-migration/02-configure-rspamd.sh
servers = "127.0.0.1";
EOF

log "Enabling greylisting module (delays unknown senders, redis-backed)"
cat > /etc/rspamd/local.d/greylist.conf <<'EOF'
# Added by rspamd-migration/02-configure-rspamd.sh
enabled = true;
EOF

log "Configuring milter proxy worker on 127.0.0.1:11332 (alongside OpenDKIM on 8891)"
cat > /etc/rspamd/local.d/worker-proxy.inc <<'EOF'
# Added by rspamd-migration/02-configure-rspamd.sh
bind_socket = "127.0.0.1:11332";
milter = yes;
timeout = 120s;
upstream "local" {
  default = yes;
  self_scan = yes;
}
EOF

log "Enabling extended spam-result headers (adds X-Spamd-Result / X-Spam-Status)"
cat > /etc/rspamd/local.d/milter_headers.conf <<'EOF'
# Added by rspamd-migration/02-configure-rspamd.sh
# extended_spam_headers turns on X-Spam-Status (SpamAssassin-compatible
# "Yes/No, score=..." format) in addition to rspamd's own X-Spamd-Result,
# which is always emitted by default. The Dovecot sieve rule checks both,
# so it doesn't matter which one ends up carrying the flag on your rspamd version.
extended_spam_headers = true;
EOF

log "Checking rspamd config syntax"
if rspamadm configtest; then
    log "Config OK"
else
    err "rspamd config test FAILED — not restarting rspamd. Fix the error above."
    exit 1
fi

log "Restarting rspamd"
systemctl restart rspamd
sleep 1
systemctl --no-pager status rspamd | head -10

echo
log "Checking milter port is listening"
ss -ltnp 2>/dev/null | grep ':11332' || warn "Nothing listening on 11332 yet — check 'journalctl -u rspamd -n 50'"

echo
log "Done. rspamd is listening for milter connections on 127.0.0.1:11332."
log "Nothing sends it mail yet — next: run 03-configure-postfix.sh"
