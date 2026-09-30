# agent-vault production state — vps-1558ffa7

Updated when deployment state changes. Phase-2 docs in ~/.hermes/cache/scratch/ are EPHEMERAL (24h prune) — the durable facts live here and in /opt/agent-vault-docs/ + the git repo.

## Deployed (post-cutover)

- Binary: v0.39.3 pinned, attestation-verified, at /usr/local/bin/agent-vault
- Service: `agent-vault.service` (system unit, user agent-vault, StateDirectory=/var/lib/agent-vault, hardening incl. ProtectSystem=strict, LoadCredential=avmaster:/etc/agent-vault/master, ExecStart wrapper /usr/local/bin/agent-vault-cred-wrapper feeding `--password-stdin`)
- Listeners: 127.0.0.1:14321 (mgmt) + 127.0.0.1:14322 (MITM proxy) — loopback only
- UI over tailnet: `tailscale serve --bg --https=443 http://127.0.0.1:14321` → https://vps-ovh.tail95f2ee.ts.net (disable: `tailscale serve --https=443 off`)
- Secrets (root 0600): /etc/agent-vault/master (vault KEK), owner.creds (owner login operator@vps-1558ffa7.local), hermes-agent-token
- Backups pending destruction (contain OLD key): /root/av-prechange-backup/ + /root/cutover-backup/ (full 4.2G pristine tree — also the rollback source until stability is confirmed)

## Cutover: DONE

- Dedicated `hermes` user (uid 1003, NO docker group, NO sudo) created; tree migrated from /root/cutover-backup with FULL-TREE path rewrite (config-only fixes break venv shebangs/pyvenv.cfg/launchers)
- Gateway now runs as a SYSTEM unit /etc/systemd/system/hermes-gateway.service (User=hermes, Requires+After agent-vault.service, ProtectHome=false + ProtectSystem=strict + ReadWritePaths=/home/hermes/.hermes — ProtectHome=true fails at step EXEC with ENOENT for home-resident runtimes)
- Old user-unit gateway disabled; CLI launcher published at /home/hermes/.local/bin/hermes
- nftables table `inet av_hermes` LIVE (output hook priority 10, skuid 1003: allow 127.0.0.1:14322 + DNS 53, drop rest); auto-revert armed → all verifies passed → disarmed; survived docker restart + fail2ban reload
- Verified: hermes uid direct internet = timeout; via proxy = 200; gateway + Slack connected through proxy; migrated-user model call OK; /proc environ scan clean (dotenv memory caveat: old key may persist in leftover ubuntu-session processes until retirement)

## Vault `hermes` service rules (10, all :443)

- openrouter.ai — bearer → OPENROUTER_API_KEY (NEW spend-limited $20 key, verified distinct from old via owner-side equality test — provider /key endpoint is USER-AGGREGATE and cannot fingerprint)
- slack.com + *.slack.com — passthrough (Slack tokens still in Hermes .env; broker in later phase)
- portal.nousresearch.com, hermes-agent.nousresearch.com, raw.githubusercontent.com, nousresearch.github.io (redirect target of hermes-agent host) — passthrough
- *.github.com + github.com (apex needs its own rule) + objects.githubusercontent.com — passthrough (docs/push; git needs GIT_SSL_CAINFO behind the MITM — now set in both .env copies)
- unmatched_host_policy=deny

## Hermes wiring

- /home/hermes/.hermes/.env (0600): OPENROUTER_API_KEY=__openrouter_api_key__ + AV proxy block (AGENT_VAULT_*, HTTPS_PROXY/HTTP_PROXY with token, NO_PROXY=localhost,127.0.0.1, CA vars incl. GIT_SSL_CAINFO → ~/.hermes/av-ca.pem)
- Migration runbook + timings: /opt/agent-vault-docs/RUNBOOK.md (rehearsal: rsync 45s, chown 2s, full-tree rewrite 30s, first migrated-user run 2m11s)

## Docs

- Durable on-VPS: /opt/agent-vault-docs/ (PLAN.md, PHASE1-REPORT.md, SETUP-LOG.md, RUNBOOK.md, hermes-gateway.system-unit)
- Git record: github.com/DUDE616/agent-vault-setup (PRIVATE repo, secret-scanned; same docs + scripts)

## Pending (in order)

1. USER confirms: Slack test message reacts; external `nc -zv <public-ip> 14321 14322` both refuse
2. USER revokes old OpenRouter key (a75...2e6) → agent verifies it 401s and brokered path keeps working
3. Retire leftover ubuntu-session processes (herdr server + interactive sessions — old key may persist in their dotenv-loaded process memory; environ scan alone is insufficient)
4. After stability confirmed: destroy /root/av-prechange-backup + /root/cutover-backup, update SETUP-LOG/deployment-state, commit final docs to the repo
5. Later phases: broker Slack tokens via vault substitutions; consider moving remaining .env secrets
