# Agent-Vault Migration — exact move vs fresh re-seed

Canonical deployment record: `abxba-org/agent-vault-setup` (vendored snapshot in
`upstream/` — treat that repo as the source of truth; do not edit the snapshot).

Current deployment (as of 2026-10): agent-vault v0.39.3, systemd `agent-vault.service`,
user `agent-vault`, data `/var/lib/agent-vault/.agent-vault` (0700), loopback-only
14321 (mgmt) + 14322 (MITM proxy), master password root 0600 `/etc/agent-vault/master`
fed via `--password-stdin` through `agent-vault-cred-wrapper`, nftables `inet av_hermes`.

## Option A — move the EXACT vault (recommended; preserves credentials, rules, audit logs)

1. **Precondition**: old OpenRouter key revocation decision settled (RUNBOOK criterion 20).
2. On the OLD VPS, as root: `bash migrations/agent-vault/export-vault.sh`
   - Stops gateway + vault, bundles `agent-vault.db` (+ ca/, mitm-ca.pem, session.json),
     `/etc/agent-vault/*` (master, owner.creds, hermes-agent-token, serve-cmd),
     `/etc/av-hermes.nft`, version + unit files, `vault-mgmt` + wrapper binaries.
   - Restarts vault + gateway on the old box afterwards (no downtime beyond seconds).
3. Copy over Tailscale only: `scp /root/vault-migration-bundle.tar.gz newvps:/root/`
4. On the NEW VPS, as root: clone this repo to /root/hermes-config, then
   `bash migrations/agent-vault/import-vault.sh`
5. Post-import verification (from `upstream/docs/RUNBOOK.md` verification pattern):
   - `curl -s http://127.0.0.1:14321/v1/health` → up
   - Owner login works (owner.creds); `vault credential get` shows OPENROUTER_API_KEY
   - Vault `hermes` exists; `unmatched_host_policy=deny` intact; 34 service rules present
   - Hermes one-shot: `env -i HOME=/home/hermes hermes -z` → model call succeeds through 14322
   - External port scan: 14321/14322 NOT reachable from public IP or tailnet (except ON window)
6. **Destroy the bundle on BOTH boxes** after verification (`shred -u /root/vault-migration-bundle.tar.gz`).

## Option B — fresh re-seed on the new VPS

Follow `upstream/docs/SETUP-LOG.md` from the top (it is the complete command-by-command
record). Differences for a fresh box:
- `wire-env.py` rewrites the new `.env` (placeholder key + proxy block).
- Re-enter credentials via the vault web UI (mgmt ON window: `sudo vault-mgmt on`)
  or owner CLI stdin — NEVER argv.
- Re-add all 34 service rules — batch them in ONE window per the approval convention.
- New CA: the vault generates `mitm-ca.pem`; hermes `.env` CA vars must point at the NEW
  `av-ca.pem` (copy from new vault, update `.env` + `config.yaml` trust paths).

## Hard-won gotchas (do not relearn)

- One-level wildcards don't match apex: `*.github.com` AND `github.com` both need rules.
- git needs `GIT_SSL_CAINFO` (in .env), not just CURL_CA_BUNDLE/SSL_CERT_FILE.
- Unit with `ProtectHome=true` + runtime under /home → EXEC ENOENT; use ProtectSystem=strict
  + ReadWritePaths. `StateDirectory=agent-vault` must exist or the unit crash-loops (226).
- `agent-vault server stop` takes no --address flag; `master-password change` wants a TTY.
- Never pass credentials via CLI argv (sudo/journal log argv) — stdin or web UI only.
  `vault credential get` (value read-back) FAILS with "Member role required" even for the
  instance owner with vault admin role (quirk, affects every key incl. OPENROUTER_API_KEY)
  — equality verification is web-UI-only; CLI `vault credential list` confirms existence.
- Pre-seeded recovery credentials (2026-10-16): RESTIC_PASSWORD, HEVY_API_KEY in vault
  `hermes` — they travel with the vault export bundle; keep source files
  (~/.restic_password, ~/HEVY/.hevy_env) in sync or delete them after migration.
- The 14321 allow rule for uid 1003 is REQUIRED in nftables — the gateway re-fetches
  credentials from mgmt after restart; 14322+DNS-only rulesets break it.
- `nftables.service` stays DISABLED on the host (its conf flushes docker tables); the
  vault egress table is persisted via the `av-hermes-nftables.service` oneshot.
- Migrating `~/.hermes` to a DIFFERENT user (ubuntu → hermes): full-tree grep rewrite of
  every text file containing the old path (venv shebangs, pyvenv.cfg, launchers) —
  `fix-paths.py` alone is NOT enough (see RUNBOOK step 2).

## Which option when

- Same-architecture Linux, you trust the source box: **Option A**. Fastest, zero rule drift.
- New box is a different OS/distro, or you want credential rotation anyway: **Option B**.
- Either way: rotate the agent token + owner password as part of the move (new box = new secrets).
