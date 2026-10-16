# hermes-config

Versioned backup of the Hermes Agent configuration on the OVH VPS (`vps-1558ffa7` / `vps-ovh.tail95f2ee.ts.net`), and the master migration kit for the move to Contabo EU (`vps-contabo`).

**Status (2026-10-16):** synced every 12h by the Hermes cron job `hermes-config-backup-sync` (job `0ed471b7d0b5`, script `scripts/backup-sync.sh`, pushes to `main`).

## What's tracked

config.yaml (settings only, no secrets), SOUL.md, PERSONAS.md, memories/, skills/, plugins/, profiles/ (structure only — profile logs are stripped), cron/, scripts/ (cron job scripts incl. backup-sync.sh, which also runs this sync), slack-manifest.json, channel_directory.json, av-ca.pem (agent-vault CA cert), migrations/ (migration kit).

## What's excluded, on purpose

- **Secrets:** `.env` (API keys), `auth.json` (OAuth tokens), `vault/`, `pairing/` — never commit these. If one ever lands in a commit, treat it as compromised: rotate the credential and rewrite history.
- **Bulk, regenerable:** `hermes-agent/` source checkout, `tools/` binaries (python/node/chromium/ffmpeg), `cache/`, `installs/`, `environments/`, `lsp/`, `models_dev_cache.json`
- **Private/dynamic:** `state.db` (chat transcripts), `state-snapshots/`, `sessions/`, `logs/`, `backups/`, kanban.db (board state), terminal-sessions/, pastes/, pending*/

## .gitignore model

Whitelist-style: ignore `/*`, then un-ignore tracked names. A stray future file (like a renamed `.env`) can't be committed by accident. Secrets are also blocked by pattern inside tracked dirs (`*.db`, `*.pem` except `av-ca.pem`, `auth.json`, `.env*`), plus a credential-regex gate in backup-sync.sh that aborts before commit/push.

## Restore (quick)

```bash
gh repo clone abxba-org/hermes-config
rsync -a hermes-config/ ~/.hermes/          # overlays; does not delete
chmod 600 ~/.hermes/config.yaml
# Secrets (.env, auth.json) are NOT in the repo — restore them separately from a vault/backup.
```

## Migration

Everything needed to move the stack to a new VPS lives in `migrations/` (full detail in `migrations/MIGRATION.md`):

- `MIGRATION.md` — transfer matrix (what moves vs what must be re-entered), restore order
- `USER.md` — the operator's own step-by-step checklist (Step 0 → decommission, gates marked)
- `restore-new-vps.sh` — guided step-by-step restore (secrets stay manual; defaults match the Contabo plan's dedicated `hermes` user layout)
- `capture-host-snapshot.sh` — refreshes `host-snapshot/` (crontab, nftables, unit files, tailscale, versions — non-secret)
- `agent-vault/` — `export-vault.sh` (old VPS) + `import-vault.sh` (new VPS) move the
  EXACT vault (credentials, rules, logs); `VAULT-MIGRATION.md` covers the move and the
  fresh re-seed path; `upstream/` is a vendored snapshot of `abxba-org/agent-vault-setup`

**Operational plan of record:** [`abxba-org/vps-migration-contabo`](https://github.com/abxba-org/vps-migration-contabo) — phased plan with operator gates. This repo is the artifact layer that plan calls.

**Vault recovery credentials already seeded (2026-10-16):** `RESTIC_PASSWORD` and `HEVY_API_KEY` live in agent-vault vault `hermes` (entered via web UI). They travel with the vault export bundle — the manual re-entry list on a new box shrinks to: Slack tokens, gh auth, tailscale, composio, Grafana remote-write key.

## Maintenance

Re-run the copy + commit when config/skills/plugins change materially. The working tree lives at `~/.hermes-git/hermes-config` (copy, not symlinks — git never touches the live `~/.hermes`). The cron job handles routine sync; run `bash ~/.hermes-git/backup-sync.sh` by hand after big changes. Agent conventions for working in this repo: see `AGENTS.md`.
