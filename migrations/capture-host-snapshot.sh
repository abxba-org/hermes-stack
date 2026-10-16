#!/usr/bin/env bash
# Capture NON-SECRET host configs into migrations/host-snapshot/ (inside this repo).
# Runs on the OLD VPS as the admin user. Safe to re-run — refreshes the snapshot dir.
# Explicitly excludes: .env, auth.json, vault data, restic password, Hevy key, SSH keys.
set -euo pipefail

SNAP="$(cd "$(dirname "$0")/.." && pwd)/migrations/host-snapshot"
mkdir -p "$SNAP"
cd "$SNAP"
rm -rf ./* 2>/dev/null || true

echo "== crontab =="
crontab -l > crontab.txt 2>/dev/null || echo "(none)" > crontab.txt

echo "== shell/git config =="
cp -p ~/.gitconfig . 2>/dev/null || true

echo "== nftables (agent-vault egress) =="
cat /etc/av-hermes.nft > av-hermes.nft 2>/dev/null || echo "(missing)" > av-hermes.nft
systemctl cat av-hermes-nftables.service > av-hermes-nftables.service.txt 2>/dev/null || true

echo "== agent-vault service surface (NO secrets: unit files + on/off tool only) =="
systemctl cat agent-vault.service > agent-vault.service.txt 2>/dev/null || true
cp -p /usr/local/bin/vault-mgmt vault-mgmt.txt 2>/dev/null || true
agent-vault --version > agent-vault-version.txt 2>/dev/null || true

echo "== grafana alloy =="
cat /etc/default/alloy > alloy-defaults.txt 2>/dev/null || true
ls /etc/alloy/ 2>/dev/null > alloy-config-listing.txt || true
# NOTE: the alloy config itself may embed the Grafana remote-write API key — do NOT copy it.
# Record only where it lives:
echo "config path per /etc/default/alloy CONFIG_FILE (not copied: may contain API key)" >> alloy-config-listing.txt

echo "== restic local-backup script (checks REPOSITORY var; redacts password file path value) =="
if [ -f ~/scripts/restic_backup.sh ]; then
  sed -E 's#(RESTIC_PASSWORD_FILE=).*#\1<redacted>#' ~/scripts/restic_backup.sh > restic_backup.sh.txt
fi
echo "password file: ~/.restic_password (0600, NOT copied — back it up to the vault manually)" > restic-notes.txt

echo "== tailscale (status only, no node keys) =="
tailscale status > tailscale-status.txt 2>/dev/null || echo "(tailscale not available)" > tailscale-status.txt
tailscale serve status > tailscale-serve.txt 2>/dev/null || true

echo "== composio (connected toolkit NAMES only) =="
composio profile list 2>/dev/null || composio apps list 2>/dev/null || echo "(composio CLI n/a)" > composio-profiles.txt

echo "== hermes runtime facts =="
hermes --version > hermes-version.txt 2>/dev/null || true
python3 --version > python-version.txt 2>/dev/null || true
uname -a > uname.txt 2>/dev/null || true

echo "== HEVY pointer (repo is its own git remote; secrets stay out) =="
{ echo "canonical repo: https://github.com/abxba-org/hevy.git (private)"
  echo "crontab entry: 12h hevy_watch.py --tz +05:30 (see crontab.txt)"
  echo "secret: ~/HEVY/.hevy_env HEVY_API_KEY — re-enter manually, gitignored"
} > hevy-notes.txt

echo
echo "Snapshot written to: $SNAP"
echo "Review before committing: grep -rIiE 'key|token|password|secret' $SNAP || echo clean"
