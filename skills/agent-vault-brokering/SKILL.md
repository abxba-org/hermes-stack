---
name: agent-vault-brokering
version: 1.0.0
author: ABXBA + Hermes Agent
license: MIT
description: Use when setting up or operating Infisical agent-vault.
tags: [security, secrets, brokering, nftables]
related_skills: [hermes-agent]
---

# agent-vault credential brokering (vps-1558ffa7)

## When to Use

Use when installing, configuring, testing, upgrading, or troubleshooting Infisical agent-vault credential brokering for AI agents on this VPS, or when brokering a new credential type (API key, Slack token) through it.

## Always-on rules

- Plan first; every phase change (sandbox → production, user migration, firewall, key revocation) needs the user's explicit go. Research runs via a subagent; the user reviews and hardens plans line-by-line.
- NEVER pass a secret as a command-line argument — sudo logs argv to /var/log/auth.log and the user journal. Enter credentials via the web UI over the tailnet, or stdin (`--password-stdin`).
- Sandbox = throwaway users/container with dummy credentials, separate UIDs; destroy it after the report.
- Arm the nftables auto-revert BEFORE applying rules: `systemd-run --on-active=5m --unit=<revert-name> nft delete table inet <tbl>`; cancel deliberately after re-tests. SSH runs as uid 1000 — UID-scoped rules cannot lock it out, but arm the revert anyway.
- Kill processes by user (`pkill -u <user>`), never `pkill -f` — `-f` matches its own command string and SIGTERMs the running shell.
- Dedicated nftables table with explicit hook priorities; re-test after `systemctl restart docker` and `fail2ban-client reload` — both rewrite their own tables.

## Procedure

1. **Verify the release** before anything runs: `gh attestation verify <tarball> --repo Infisical/agent-vault`. Distro gh is too old for this subcommand — fetch a current gh release and checksum-match it first. Fallback: `GET /repos/{owner}/{repo}/attestations/sha256:<digest>` proves bundle existence; full crypto verify still needs current gh.
2. **Run the server** under a dedicated system user with a systemd unit. Master password reaches it via an ExecStart wrapper feeding `--password-stdin < $CREDENTIALS_DIRECTORY/<name>` (LoadCredential=). The env-var approach leaves the master readable in /proc/<pid>/environ for the process lifetime — never use it.
3. **Vault config via CLI as the service user**: `sudo -u agent-vault env HOME=/var/lib/agent-vault agent-vault ...`. Owner account = first `auth register`. Service rules: `vault service add --name <n> --host <host>:<port> --auth-type bearer|api-key|custom|passthrough --token-key <KEY>`. Rules may reference credentials that don't exist yet.
4. **Strict deny is NOT the default** — unmatched hosts forward as plain proxy traffic until you PATCH `/v1/vaults/{name}/settings` with `{"unmatched_host_policy":"deny"}` (owner session cookie from `POST /v1/auth/login`).
5. **Agent tokens**: `agent create <name> --vault <v>:proxy --token-only`. Proxy-role tokens cannot read/set credentials or mutate services; they CAN enumerate credential key names (accepted, low). Store tokens root 0600 until the consuming user exists.
6. **Wire the agent**: dummy placeholder for the real key in the app's env file + `AGENT_VAULT_ADDR/TOKEN/VAULT` + `HTTPS_PROXY/HTTP_PROXY=http://<token>:<vault>@127.0.0.1:<port>` + CA vars (`SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE`, `CURL_CA_BUNDLE`, `NODE_EXTRA_CA_CERTS`) — then restart the consuming service and verify via request logs (`GET /v1/vaults/{name}/logs`).
7. **Out-of-scope infra hosts get PASSTHROUGH rules** (allowlist without injection — for services holding their own tokens), chosen by the user, never added silently. Never broad wildcards (`*.com`, `0.0.0.0/0`). One-level wildcard `*.slack.com` covers socket-mode wss upgrades (status 101).
8. **Network enforcement**: nftables `skuid <uid>` rules in an output chain, priority 10: allow proxy port + DNS, drop the rest. HTTPS_PROXY alone is not a boundary — unsetting it must not restore direct access.
9. **Fail-closed check**: stop agent-vault → agent requests fail with no fallback; restart → recovery. Boot ordering via systemd Requires=/After= on the agent's unit.

## Pitfalls

- The MITM issues a cert for UNMATCHED hosts before returning the 403 — "no certs for non-allowlisted hosts" is not implemented. Compensating controls: CA trusted only by the agent's process env (never the system store) + strict deny.
- The fetched CA bundle contains ONLY the vault CA. Any TLS not routed through the proxy fails closed. Scope CA vars to the agent's env file.
- HTTP/2 is downgraded to HTTP/1.1 on the client leg (expected, functional).
- Upstreams that echo auth headers reveal the injected credential in responses — inherent to brokering; real APIs don't echo.
- netguard blocks loopback/private/CGNAT/metadata by resolved IP — a localhost test server is unreachable via the proxy BY DESIGN (that block is a passing test, not a bug).
- httpbin.org caps /bytes at 100KiB and /stream at 100 lines — use `speed.cloudflare.com/__down?bytes=N` for byte-exact large-response tests.
- systemd units: missing `StateDirectory=` with ProtectSystem=strict + ReadWritePaths → start fails 226/NAMESPACE (mount namespacing, "No such file or directory").
- `.env`-style runtime dotenv: vars are loaded into Python memory at start, NOT visible in /proc/<pid>/environ — verify wiring via request logs, not environ.

## References

- `references/acceptance-tests.md` — full sandbox test matrix + production acceptance criteria.
- `references/deployment-state.md` — current production layout, paths, and remaining phases.