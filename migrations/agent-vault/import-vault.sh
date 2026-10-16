#!/usr/bin/env bash
# agent-vault IMPORT — run on the NEW VPS as root.
# Restores the exact vault state from export-vault.sh's bundle.
# Assumes the hermes-stack repo is cloned at /root/hermes-stack (for vendored upstream scripts).
set -euo pipefail
umask 077

BUNDLE=/root/vault-migration-bundle.tar.gz
REPO=/root/hermes-stack
STAGE=$(mktemp -d /root/vault-import.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT

[ "$(id -u)" -eq 0 ] || { echo "FATAL: run as root"; exit 1; }
[ -f "$BUNDLE" ] || { echo "FATAL: $BUNDLE not found — copy it from the old VPS first"; exit 1; }
[ -d "$REPO/migrations/agent-vault/upstream/scripts" ] || { echo "FATAL: clone hermes-config to $REPO first (or edit REPO=)"; exit 1; }

echo "== Unpacking bundle =="
tar -C "$STAGE" -xzf "$BUNDLE"
WANT=$(cat "$STAGE/VERSION" | awk '{print $3}')
echo "Bundle vault version: $WANT"

echo "== Installing agent-vault binary ($WANT) if not already present =="
if ! command -v agent-vault >/dev/null || ! agent-vault --version | grep -q "$WANT"; then
  echo "  -> download the $WANT release from github.com/Infisical/agent-vault/releases"
  echo "     install to /usr/local/bin/agent-vault (0755), then re-run this script"
  exit 1
fi

echo "== Creating user + stopping anything fresh =="
id agent-vault &>/dev/null || useradd -r -M -d /var/lib/agent-vault -s /usr/sbin/nologin agent-vault
systemctl stop agent-vault.service 2>/dev/null || true

echo "== Restoring state =="
install -d -m 700 -o agent-vault -g agent-vault /var/lib/agent-vault/.agent-vault
cp -a "$STAGE/data/." /var/lib/agent-vault/.agent-vault/
rm -f /var/lib/agent-vault/.agent-vault/agent-vault.pid
install -d -m 700 /etc/agent-vault
cp -a "$STAGE/etc/." /etc/agent-vault/
# Preserve per-file owners recorded in the bundle (master/owner.creds = root, agent token = admin user)
chown root:root /etc/agent-vault/master /etc/agent-vault/owner.creds 2>/dev/null || true
chmod 600 /etc/agent-vault/*
[ -f "$STAGE/av-hermes.nft" ] && { install -m 600 "$STAGE/av-hermes.nft" /etc/av-hermes.nft; }

echo "== Installing systemd unit + wrapper from vendored upstream scripts =="
install -m 755 "$REPO/migrations/agent-vault/upstream/scripts/agent-vault-cred-wrapper" /usr/local/bin/
[ -f "$STAGE/agent-vault-cred-wrapper" ] && install -m 755 "$STAGE/agent-vault-cred-wrapper" /usr/local/bin/agent-vault-cred-wrapper
install -m 755 "$STAGE/vault-mgmt" /usr/local/bin/vault-mgmt 2>/dev/null || true
# NOTE: the vendored unit uses LoadCredential=avmaster:/etc/agent-vault/master — matches our layout.
systemctl daemon-reload

echo "== Enabling + starting =="
systemctl daemon-reload
systemctl enable agent-vault.service
systemctl start agent-vault.service
sleep 3
systemctl is-active agent-vault.service

echo "== Verifying mgmt API (localhost only) =="
for i in 1 2 3 4 5; do
  curl -fsS -o /dev/null http://127.0.0.1:14321/v1/health && break || sleep 2
done
curl -fsS http://127.0.0.1:14321/v1/health >/dev/null && echo "OK: mgmt API up on 14321" || { echo "FATAL: mgmt API not responding — check journalctl -u agent-vault"; exit 1; }

echo
echo "DONE. Remaining manual steps (see migrations/agent-vault/VAULT-MIGRATION.md):"
echo "  1. Install /etc/av-hermes.nft + oneshot unit (vendored: av-hermes-nftables pattern) AFTER the hermes user exists"
echo "  2. Verify vault credential equality: vault credential get (owner) vs old VPS records"
echo "  3. Point Hermes .env AGENT_VAULT_ADDR at the NEW host; agent token in /etc/agent-vault/hermes-agent-token"
echo "  4. DESTROY /root/vault-migration-bundle.tar.gz on both boxes once verified"
