#!/usr/bin/env bash
# Guided restore on the NEW VPS — prints/executes the ordered migration steps.
# Run as the admin user. Secrets are NEVER read, moved, or printed by this script:
# every secret step pauses and tells you exactly what to type/where from.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
NEW_HERMES_HOME="${HERMES_HOME:-/home/hermes/.hermes}"
# Contabo plan (abxba-org/vps-migration-contabo) locks the dedicated-user layout:
# hermes uid 1003, no sudo, gateway system unit. Override only if deliberately deviating.
HERMES_USER="${HERMES_USER:-hermes}"

banner() { printf '\n===== %s =====\n' "$*"; }

banner "0. Preconditions (interactive)"
echo "  [ ] Out-of-band access to new VPS confirmed (provider console)"
echo "  [ ] Old VPS bundle copied: /root/vault-migration-bundle.tar.gz (Tailscale scp only)"
echo "  [ ] tailscale up on new VPS:  tailscale up --hostname=<new-name>"
echo "  Press ENTER when ready; Ctrl-C to abort."
read -r

banner "1. Vault — exact move"
echo "  Run as root on the NEW VPS:"
echo "    git clone https://github.com/abxba-org/hermes-config /root/hermes-config"
echo "    bash /root/hermes-config/migrations/agent-vault/import-vault.sh"
echo "  VERIFY per migrations/agent-vault/VAULT-MIGRATION.md step 5."
read -r -p "  Vault imported and verified? [y/N] " a; [ "${a:-n}" = y ] || exit 1

banner "2. Hermes install"
command -v hermes >/dev/null 2>&1 || {
  echo "  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash"
  echo "  (run it now in another shell, then press ENTER)"
  read -r
}
hermes --version

banner "3. Config overlay from this repo"
gh auth status >/dev/null 2>&1 || { echo "  Run: gh auth login  (first)"; exit 1; }
rsync -a "$REPO/" "$NEW_HERMES_HOME/" --exclude .git --exclude migrations
if [ "$HERMES_USER" != "ubuntu" ]; then
  echo "  Dedicated-user layout: full-tree path rewrite REQUIRED (venv shebangs/pyvenv.cfg):"
  echo "    see migrations/agent-vault/upstream/docs/RUNBOOK.md step 2 grep-loop"
fi
chmod 600 "$NEW_HERMES_HOME/config.yaml" 2>/dev/null || true

banner "4. Secrets — MANUAL (nothing below is automated)"
echo "  a. ~/.hermes/.env — re-enter: SLACK_APP_TOKEN, SLACK_BOT_TOKEN, SLACK_ALLOWED_USERS,"
echo "     SLACK_HOME_CHANNEL, AGENT_VAULT_ADDR (new host), AGENT_VAULT_TOKEN, AGENT_VAULT_VAULT=hermes"
echo "     Then regenerate the proxy block:  python3 $REPO/migrations/agent-vault/upstream/scripts/wire-env.py"
echo "  b. auth.json — hermes setup / provider login (OpenRouter pool)"
echo "  c. ~/HEVY/.hevy_env — HEVY_API_KEY from hevy.com/settings?developer"
echo "  d. ~/.restic_password — CRITICAL: confirm it matches the vault copy before first restore"
echo "  e. gh auth login, tailscale (done), composio link linear/slack/github"
read -r -p "  All secrets entered? [y/N] " a; [ "${a:-n}" = y ] || exit 1

banner "5. Gateway service + nftables"
echo "  As root:"
echo "    install -m644 $REPO/migrations/agent-vault/upstream/scripts/hermes-gateway.system-unit \\"
echo "           /etc/systemd/system/hermes-gateway.service && systemctl daemon-reload"
echo "    Check the unit's nftables expectations: uid of $HERMES_USER must match the rule"
echo "    (old rule targets uid 1003=hermes; if you run as ubuntu, regenerate /etc/av-hermes.nft)"
echo "    install -m600 migrations/host-snapshot/av-hermes.nft /etc/av-hermes.nft"
echo "    (oneshot unit: see migrations/host-snapshot/av-hermes-nftables.service.txt)"
read -r -p "  Gateway unit + nftables installed? [y/N] " a; [ "${a:-n}" = y ] || exit 1

banner "6. Host extras"
echo "  - crontab: crontab migrations/host-snapshot/crontab.txt (check paths/keys first!)"
echo "  - gitconfig: cp migrations/host-snapshot/.gitconfig ~/.gitconfig"
echo "  - HEVY: gh repo clone abxba-org/hevy ~/HEVY && create ~/HEVY/.hevy_env (step 4c)"
echo "  - alloy: install grafana-alloy, set CONFIG_FILE + re-enter remote-write key"
echo "  - backup cron: re-create the 12h backup job inside hermes (see migrations/README note)"

banner "7. End-to-end verify"
echo "  - hermes gateway live: message the bot from Slack"
echo "  - vault request log (owner): proxied OpenRouter calls appear"
echo "  - external scan: 14321/14322 NOT reachable from public IP"
echo "  - cron: hermes cron list → backup job scheduled, ticker advancing"
echo "  - shred the vault bundle on BOTH boxes: shred -u /root/vault-migration-bundle.tar.gz"
echo
echo "Migration checklist complete."
