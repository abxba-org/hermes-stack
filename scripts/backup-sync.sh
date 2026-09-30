#!/usr/bin/env bash
# Hermes config backup sync — whitelist copy + secret-scan gate + push.
# Never runs as root; never touches the live ~/.hermes (read-only source).
set -euo pipefail

export HOME=/home/ubuntu
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
umask 077

SRC=/home/ubuntu/.hermes
WT=/home/ubuntu/.hermes-git/hermes-config
LOG=/home/ubuntu/.hermes-git/sync.log
LOCK=/home/ubuntu/.hermes-git/.sync.lock

log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" >> "$LOG"; }

# --- single instance ---------------------------------------------------------
exec 9>"$LOCK"
flock -n 9 || { log "SKIP: another sync is running"; exit 0; }

# --- sanity: never run on unexpected paths -----------------------------------
[ -d "$WT/.git" ] && [ -d "$SRC/skills" ] || { log "FATAL: unexpected layout"; exit 1; }
[ "$(id -u)" -eq 0 ] && { log "FATAL: refusing to run as root"; exit 1; }

# --- refresh working tree (read-only pull from live config) -------------------
cd "$WT"
for item in config.yaml SOUL.md PERSONAS.md slack-manifest.json channel_directory.json av-ca.pem; do
    cp -p "$SRC/$item" . 2>/dev/null || true
done
rsync -a --delete "$SRC/skills/"   skills/
rsync -a --delete "$SRC/plugins/"  plugins/
rsync -a --delete "$SRC/memories/" memories/
rsync -a           "$SRC/profiles/" profiles/ 2>/dev/null || true
rsync -a           "$SRC/cron/"     cron/     2>/dev/null || true
rsync -a --delete "$SRC/scripts/"  scripts/  2>/dev/null || true

# strip runtime noise + any db/log artifacts
find skills plugins profiles cron memories scripts \
     \( -name '__pycache__' -o -name 'node_modules' -o -name '.venv' \) -type d \
     -prune -exec rm -rf {} + 2>/dev/null || true
find skills plugins profiles cron memories scripts \
     -type f \( -name '*.db' -o -name '*.db-shm' -o -name '*.db-wal' \
        -o -name '*.sqlite*' -o -name '*.log' -o -name 'auth.json' \
        -o -name '.env*' -o -name '*.env' \) -delete 2>/dev/null || true
rm -f profiles/*/logs/* 2>/dev/null || true

# --- secret-scan gate: abort BEFORE commit/push on real credential patterns ---
HITS=$(grep -rInE \
  '(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|gho_[A-Za-z0-9]{36}|ghs_[A-Za-z0-9]{36}|sk-ant-[A-Za-z0-9-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|glpat-[A-Za-z0-9_-]{20,}|shpat_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{40,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' \
  --exclude-dir=.git . 2>/dev/null || true)
if [ -n "$HITS" ]; then
    printf '%s BLOCKED: credential pattern matched — NOT committed/pushed\n' \
        "$(date -u +%FT%TZ)" >> "$LOG"
    printf '%s\n' "$HITS" | head -20 >> "$LOG"
    echo "BACKUP BLOCKED: credential-like pattern in staged files; nothing committed or pushed. Details: ~/.hermes-git/sync.log"
    exit 2
fi

# --- commit + push ------------------------------------------------------------
git add -A
if git -c core.hooksPath=/dev/null diff --cached --quiet; then
    log "OK: no changes"
    exit 0
fi
git -c core.hooksPath=/dev/null commit -q -m "Scheduled backup sync $(date -u +%F)" \
    && git push -q origin main \
    && log "OK: pushed $(git rev-parse --short HEAD)" \
    || { log "ERROR: commit/push failed"; echo "BACKUP ERROR: commit or push failed — check ~/.hermes-git/sync.log"; exit 3; }
