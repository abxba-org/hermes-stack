# AGENTS.md — conventions for agents working in this repo

This is the master backup + migration-kit repo for the Hermes Agent stack on the OVH VPS
(`vps-1558ffa7` / `vps-ovh.tail95f2ee.ts.net`). Working tree: `~/.hermes-git/hermes-stack`.
It is read-only with respect to the live `~/.hermes` — never symlink, never write back.

## Hard rules

1. **No secrets, ever.** No `.env`, `auth.json`, tokens, passwords, private keys, or
   `.hevy_env`-style files. The whitelist `.gitignore` + the credential-regex gate in
   `scripts/backup-sync.sh` (aborts before commit/push) enforce this — do not weaken either.
   If a credential lands in a commit: rotate it, then rewrite history.
2. **The gate is a feature.** A `BACKUP BLOCKED` exit from backup-sync.sh means a
   credential-like pattern matched. Fix the staged content, never the pattern.
3. **Whitelist gitignore.** New top-level dirs must be added explicitly (`!/<name>/`)
   or they silently won't be committed. Check `git status --short` after adding anything.
4. **Runtime noise stays out.** `__pycache__/`, `node_modules/`, `.venv/`, `*.db`,
   `*.log` are stripped by backup-sync.sh on every refresh — don't hand-commit them.
5. **Shell hygiene:** `set -euo pipefail`, `umask 077`, refuse root, single-instance
   flock — follow the existing style in `scripts/backup-sync.sh` and `migrations/*/*.sh`.

## Layout

- Repo root — the live `~/.hermes` whitelist copy (config.yaml, skills/, plugins/,
  memories/, profiles/, cron/, scripts/, SOUL.md, PERSONAS.md, manifests).
- `migrations/` — the migration kit:
  - `MIGRATION.md` — transfer matrix + restore order (start here)
  - `restore-new-vps.sh` — guided restore runner (HERMES_USER defaults to the Contabo
    plan's dedicated `hermes` user; secrets steps always pause for manual entry)
  - `capture-host-snapshot.sh` → `host-snapshot/` — non-secret host config captures
  - `agent-vault/export-vault.sh` (old VPS) / `import-vault.sh` (new VPS) — exact vault
    move; `agent-vault/VAULT-MIGRATION.md` + `agent-vault/upstream/` (vendored snapshot
    of `abxba-org/agent-vault-setup` — that repo is canonical, never edit the snapshot)

## Related repos (do not duplicate their content here)

- `abxba-org/vps-migration-contabo` — operational migration plan (Phases 0–I, operator
  gates). Where it and this repo disagree, it wins.
- `abxba-org/agent-vault-setup` — vault deployment record (canonical for vault setup).
- `abxba-org/hevy` — HEVY workout scripts; has its own secrets handling (.hevy_env gitignored).

## Sync procedure

Routine sync is the Hermes cron job `hermes-config-backup-sync` (every 720m). After
material changes run `bash ~/.hermes-git/backup-sync.sh` by hand and confirm the
`OK: pushed <sha>` line in `~/.hermes-git/sync.log`. If the job shows "Overdue" in
`hermes cron list`, the cron ticker stalled — fix with
`sudo systemctl restart hermes-gateway.service`.

## Vault notes (agent-vault, port 14321 mgmt / 14322 proxy, loopback-only)

- Credentials are entered via the web UI only (`sudo vault-mgmt on`, 30-min auto-OFF),
  never CLI argv. Owner CLI session for read-only ops lives in `~/.agent-vault`
  (revoke after migration day: `agent-vault auth sessions revoke`).
- `vault credential get` read-back fails "Member role required" even for the owner —
  quirk; `vault credential list` verifies existence, UI verifies equality.
- Seeded recovery credentials: `RESTIC_PASSWORD`, `HEVY_API_KEY` (2026-10-16).
