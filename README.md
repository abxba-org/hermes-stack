# hermes-config

Versioned backup of the Hermes Agent configuration on the OVH VPS (`vps-1558ffa7` / `vps-ovh.tail95f2ee.ts.net`).

## What's tracked

config.yaml (settings only, no secrets), SOUL.md, PERSONAS.md, memories/, skills/, plugins/, profiles/ (structure only — profile logs are stripped), cron/ (job definitions live in config.yaml; this tracks runtime state), slack-manifest.json, channel_directory.json, av-ca.pem (agent-vault CA cert).

## What's excluded, on purpose

- **Secrets:** `.env` (API keys), `auth.json` (OAuth tokens), `vault/`, `pairing/` — never commit these. If one ever lands in a commit, treat it as compromised: rotate the credential and rewrite history.
- **Bulk, regenerable:** `hermes-agent/` source checkout, `tools/` binaries (python/node/chromium/ffmpeg), `cache/`, `installs/`, `environments/`, `lsp/`, `models_dev_cache.json`
- **Private/dynamic:** `state.db` (chat transcripts), `state-snapshots/`, `sessions/`, `logs/`, `backups/`, kanban.db (board state), terminal-sessions/, pastes/, pending*/

## .gitignore model

Whitelist-style: ignore `/*`, then un-ignore tracked names. A stray future file (like a renamed `.env`) can't be committed by accident. Secrets are also blocked by pattern inside tracked dirs (`*.db`, `*.pem` except `av-ca.pem`, `auth.json`, `.env*`).

## Restore

```bash
gh repo clone DUDE616/hermes-config
rsync -a hermes-config/ ~/.hermes/          # overlays; does not delete
chmod 600 ~/.hermes/config.yaml
# Secrets (.env, auth.json) are NOT in the repo — restore them separately from a vault/backup.
```

## Maintenance

Re-run the copy + commit when config/skills/plugins change materially. The working tree lives at `~/.hermes-git/hermes-config` (copy, not symlinks — git never touches the live `~/.hermes`).
