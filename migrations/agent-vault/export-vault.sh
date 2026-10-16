#!/usr/bin/env bash
# agent-vault EXPORT — run on the OLD VPS as root.
# Bundles the complete vault state (encrypted SQLite + CA + master + tokens)
# so the new VPS gets the EXACT vault, not a re-seed.
# Output: /root/vault-migration-bundle.tar.gz (0600) — copy off-box over Tailscale scp only.
set -euo pipefail
umask 077

BUNDLE=/root/vault-migration-bundle.tar.gz
STAGE=$(mktemp -d /root/vault-export.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT

[ "$(id -u)" -eq 0 ] || { echo "FATAL: run as root"; exit 1; }
[ -d /var/lib/agent-vault/.agent-vault ] || { echo "FATAL: vault data dir missing"; exit 1; }

echo "== Recording versions =="
agent-vault --version | tee "$STAGE/VERSION"
systemctl is-enabled agent-vault.service av-hermes-nftables.service > "$STAGE/unit-states" 2>&1 || true
systemctl cat agent-vault.service > "$STAGE/agent-vault.service.current" 2>/dev/null || true
systemctl cat av-hermes-nftables.service > "$STAGE/av-hermes-nftables.service.current" 2>/dev/null || true
cp -p /usr/local/bin/vault-mgmt "$STAGE/vault-mgmt" 2>/dev/null || true
cp -p /usr/local/bin/agent-vault-cred-wrapper "$STAGE/agent-vault-cred-wrapper" 2>/dev/null || true

echo "== Stopping gateway + vault =="
systemctl stop hermes-gateway.service || true
systemctl stop agent-vault.service
sleep 2
# Vault must be fully down: WAL/SHM only land in the tar if the DB is closed.
pgrep -u agent-vault -f agent-vault >/dev/null && { echo "FATAL: vault still running"; exit 1; }

echo "== Staging state =="
mkdir -p "$STAGE/data" "$STAGE/etc"
# Live vault state (credentials, service rules, audit logs, CA, owner session)
cp -a /var/lib/agent-vault/.agent-vault/. "$STAGE/data/"
rm -f "$STAGE/data/agent-vault.pid"
# Root-owned secrets fed via LoadCredential + owner login + agent token
cp -a /etc/agent-vault/. "$STAGE/etc/"
# nftables egress enforcement for uid 1003 (hermes)
cp -a /etc/av-hermes.nft "$STAGE/av-hermes.nft" 2>/dev/null || echo "WARN: /etc/av-hermes.nft missing" >&2

echo "== Bundling =="
tar -C "$STAGE" -czf "$BUNDLE" .
chmod 600 "$BUNDLE"

echo "== Restarting services (old VPS stays live) =="
systemctl start agent-vault.service
sleep 2
systemctl start hermes-gateway.service
sleep 3
systemctl is-active agent-vault.service hermes-gateway.service

echo
echo "DONE: $BUNDLE ($(du -h "$BUNDLE" | cut -f1))"
echo "Copy it off-box:  scp $BUNDLE <new-vps>:/root/   # over Tailscale, never public internet"
echo "Then run import-vault.sh on the new VPS."
