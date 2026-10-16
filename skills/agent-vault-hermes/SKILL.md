---
name: agent-vault-hermes
description: Use when working on Hermes agent-vault credential brokering.
---

# Agent Vault for Hermes (vps-ovh)

HOST IDENTITY: vps-ovh.tail95f2ee.ts.net IS vps-1558ffa7 — one box, two names (tailnet 100.79.32.56, public 57.129.161.166). The agent runs on the vault host with passwordless sudo; authorization gates still apply to every change.

Full record: repo `DUDE616/agent-vault-setup` (docs/SETUP-LOG.md = every command); server copy at /opt/agent-vault-docs/.

## Architecture (as deployed)
- agent-vault v0.39.3, systemd `agent-vault.service`, user `agent-vault` (system, nologin), data `/var/lib/agent-vault/.agent-vault` (0700). Loopback only: 14321 mgmt (Tailscale Serve → https://vps-ovh.tail95f2ee.ts.net), 14322 MITM proxy (never exposed).
- Master password: root 0600 `/etc/agent-vault/master`, fed via `--password-stdin < $CREDENTIALS_DIRECTORY/avmaster` from a wrapper — env-var mode leaves the master in /proc/<pid>/environ (daemonized `-d` path wipes it, foreground does NOT).
- Vault `hermes`, unmatched_host_policy=deny (must be PATCHed — default forwards unmatched hosts!). Credential OPENROUTER_API_KEY = new dedicated key (f52...54a3); old key a75...2e6 kept alive by ABXBA's choice (deviation).
- Service rules (34 entries, all hosts unique, deduped 2026-09-30): openrouter bearer; everything else passthrough — slack.com, *.slack.com, portal + hermes-agent + hermes-assets .nousresearch.com, nousresearch.github.io, raw + objects + release-assets .githubusercontent.com, *.github.com, github.com, pypi.org, files.pythonhosted.org, registry.npmjs.org, npmjs.com, backend/app/api .composio.dev, composio.dev, api.firecrawl.dev, speed.cloudflare.com, httpbin.org, huggingface.co, cdn-lfs.huggingface.co, *.hf.co, deb.debian.org, security.debian.org, archive.ubuntu.com, security.ubuntu.com, api.openai.com, api.anthropic.com, us.i.posthog.com, vps-ovh.tail95f2ee.ts.net. NOTE: api.composio.dev is PASSTHROUGH — the older bearer rule (COMPOSIO_API_KEY injection) was removed in the dedupe because the credential's existence couldn't be confirmed (credentials endpoint 404s even for owner Bearer).
- Owner mgmt auth: Bearer token from /var/lib/agent-vault/.agent-vault/session.json (owner CLI session, 0600 agent-vault) — works on mgmt API; owner LOGIN password is separate from the master file. Batch-add: POST /v1/vaults/hermes/services {"services":[{name,host,auth:{type:"passthrough"}}]}; upserts by name; name min 3 chars.
- Hermes runs as system user `hermes` (uid 1003, NO groups/sudo), gateway = system unit `hermes-gateway.service` (Requires/After agent-vault). User-unit gateway disabled.
- Hermes .env: placeholder key `__openrouter_api_key__` + proxy block (HTTPS_PROXY=http://<token>:hermes@127.0.0.1:14322, CA vars all → av-ca.pem, GIT_SSL_CAINFO, NO_PROXY=localhost,127.0.0.1) + AGENT_VAULT_ADDR/TOKEN/VAULT → mgmt 14321.
- nftables `inet av_hermes`: uid 1003 output — allow 127.0.0.1:14321 + :14322 + DNS 53, drop rest (persisted since 2026-09-30, see Findings for drill procedure).

## Hard-won gotchas
- One-level wildcard `*.github.com` does NOT match bare apex `github.com` — apex needs its own rule.
- git ignores CURL_CA_BUNDLE/SSL_CERT_FILE — needs GIT_SSL_CAINFO env (in .env) or http.sslCAInfo.
- Unit with ProtectHome=true + runtime in /home → EXEC ENOENT; use ProtectSystem=strict + ReadWritePaths.
- `StateDirectory=` must exist; missing → 226/NAMESPACE crash loop.
- OpenRouter GET /api/v1/key returns USER-AGGREGATE label/usage — can't fingerprint a key; compare credentials via `vault credential get` (owner) equality instead.
- dotenv-loaded values are invisible in /proc/*/environ (memory only) — environ scans are necessary-not-sufficient; firewall is the real closure.
- Migrating ~/.hermes to another user: full-tree rewrite of /home/ubuntu/.hermes → new path (venv shebangs, pyvenv.cfg, launchers) — grep -rl text-files loop, NOT just .env/config.
- `agent-vault server stop` takes no --address flag; `master-password change` wants a TTY.
- Passthrough rules = allowlist + audit, NO injection: they are data-egress paths; Slack tokens still live in hermes .env (future phase: broker them, incl. substitutions feature for URL-embedded tokens).
- Never enter credentials via CLI argv (sudo/journal log argv) — web UI or stdin only. Owner CLI login works non-interactively: `auth login --email <e> --password-stdin` fed from root 0600 /etc/agent-vault/owner.creds (2 lines: email / password-with-colon; session lands in ~/.agent-vault). `vault credential get` value read-back FAILS "Member role required" even for owner+vault-admin (quirk, all keys) — equality verification is web-UI-only; `vault credential list` confirms existence. Pre-seeded 2026-10: RESTIC_PASSWORD + HEVY_API_KEY in vault hermes (travel with the export bundle).

## Migration kit (2026-10)
Complete VPS-migration bundle lives in master repo `abxba-org/hermes-stack` (renamed from hermes-config, 2026-10-16) under `migrations/`: `agent-vault/export-vault.sh` + `import-vault.sh` move the EXACT vault (stop services → tar agent-vault.db + ca + /etc/agent-vault/{master,owner.creds,hermes-agent-token} + /etc/av-hermes.nft → scp over Tailscale → restore, same version 0.39.3), `VAULT-MIGRATION.md` (exact-move vs fresh re-seed + gotchas), `MIGRATION.md` transfer matrix, `host-snapshot/` (non-secret host configs), guided `restore-new-vps.sh`. Hermes config backup cron now 12h (job 0ed471b7d0b5); ticker stalls are fixed by `sudo systemctl restart hermes-gateway.service`.

## Verification pattern
fresh-env one-shot (`env -i HOME=... hermes -z`) + vault request log (`GET /v1/vaults/hermes/logs` w/ owner cookie) + /proc scan + external nc scan of 14321/14322 + direct-vs-proxied curl as the hermes uid.

Backups: /root/cutover-backup + /root/av-prechange-backup (contain old key — destroy only after revocation).

## Mgmt exposure toggle (deployed 2026-09-30)
- `/usr/local/bin/vault-mgmt {on [--persist]|off|status|verify}` — root 0755, human-admin only; serve command recorded in root-owned /etc/agent-vault/serve-cmd.
- OFF (default posture): `tailscale serve --https=443 off` → mgmt UI localhost-only; access via `ssh -L 14321:127.0.0.1:14321` → http://localhost:14321. ON: re-arms serve, auto-OFF after 30m via systemd-run unit vault-mgmt-autorevert unless --persist.
- verify asserts: no serve/funnel entries (OFF) or the `(tailnet only)` annotation (ON); ports bind 127.0.0.1 OR [::1] only — ssh -L tunnels legitimately bind [::1], don't false-positive; funnel never on; public IP silent on 14321/14322.
- Gotchas: `tailscale funnel status` prints the serve tree even when funnel is OFF — use the `(tailnet only)` annotation as the discriminator. `serve --https=443 off` is targeted; never `serve reset`. Old OpenRouter key revocation still the blocking precondition for the migration window.
- APPROVAL CONVENTION (ABXBA, 2026-09-30): chat sessions needing new service rules must deliver them BATCHED — one consolidated list per task, never drip-fed mid-task. ABXBA approves all pending rules in a single temp-ON window (`sudo vault-mgmt on` → UI → add all → auto-OFF 30m). Sessions should first check this skill's rule inventory — the host may already be allowlisted.

## Findings 2026-09-30 (Gate-1 auth probes)
- Agent token (proxy role) on mgmt API 14321: GET /v1/vaults, /v1/vaults/hermes/services, /v1/vaults/hermes/agents, /v1/vaults/hermes/settings → 200 — metadata only (vault names, rule hosts, agent names; settings = {infisical_available, unmatched_host_policy}); logs → 403; credentials → 404 (route masked); mutation (POST invalid rule) → 403, list unchanged. Wider than the documented F2 key-name enumeration — flagged to ABXBA, pending his accept/harden call.
- Unauthenticated (localhost as hermes + tailnet leg): credentials 404, settings/logs 401 — no data either leg.
- nftables `inet av_hermes` was ABSENT live (transient cutover rules lost at reboot) — re-created + persisted 2026-09-30 evening (ABXBA go): uid 1003 output allows 127.0.0.1:14321 AND :14322 + DNS 53, all else drops. Persistence = /etc/av-hermes.nft + oneshot `av-hermes-nftables.service` (enabled). `nftables.service` deliberately stays DISABLED — its conf flushes docker's tables at boot. Verified under the table incl. docker restart + fail2ban reload; armed auto-revert used and disarmed after.
- The 14321 allow rule is REQUIRED — AGENT_VAULT_ADDR points at the mgmt port and the gateway client must re-fetch there after a restart; the cutover ruleset (14322+DNS only) would have broken post-restart credential fetch.
- True ownership check of the credentials-404 auth mask (owner-cookie comparison) still pending — optional.