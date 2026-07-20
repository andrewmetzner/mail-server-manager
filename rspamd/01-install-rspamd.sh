#!/usr/bin/env bash
# Adds the official rspamd apt repo and installs rspamd + redis-server.
# Does not touch Postfix/Dovecot config or start scanning any mail yet.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root

CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
if [[ "$CODENAME" != "bookworm" ]]; then
    warn "This box reports codename '$CODENAME', script was written for bookworm."
    confirm "Continue anyway?" || exit 1
fi

log "Installing prerequisites (wget, gpg)"
apt-get update -qq
apt-get install -y wget gpg ca-certificates

log "Adding rspamd apt repo (official rspamd.com packages)"
mkdir -p /usr/share/keyrings
wget -qO- https://rspamd.com/apt-stable/gpg.key | gpg --dearmor | tee /usr/share/keyrings/rspamd.gpg > /dev/null

cat > /etc/apt/sources.list.d/rspamd.list <<EOF
deb [signed-by=/usr/share/keyrings/rspamd.gpg] http://rspamd.com/apt-stable/ ${CODENAME} main
deb-src [signed-by=/usr/share/keyrings/rspamd.gpg] http://rspamd.com/apt-stable/ ${CODENAME} main
EOF

log "apt-get update"
apt-get update -qq

log "Installing rspamd + redis-server"
apt-get install -y rspamd redis-server

log "Capping redis memory (this box is memory-constrained — see free -h below)"
backup_file /etc/redis/redis.conf
if ! grep -q '^maxmemory 64mb' /etc/redis/redis.conf; then
    { echo ''; echo '# Added by rspamd-migration/01-install-rspamd.sh'; echo 'maxmemory 64mb'; echo 'maxmemory-policy allkeys-lru'; } >> /etc/redis/redis.conf
fi
systemctl restart redis-server

log "Enabling redis-server and rspamd (not yet wired into Postfix)"
systemctl enable --now redis-server
systemctl enable --now rspamd

echo
free -h
echo
log "Done. rspamd is running with default config, but nothing sends it mail yet."
log "Next: run 02-configure-rspamd.sh"
