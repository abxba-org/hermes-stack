# agent-vault quick reference (verified in deployment)

All facts below were verified against v0.39.3 behavior and docs.agent-vault.dev.

## Ports and listeners
- 14321 management UI/API (bind 127.0.0.1; expose remotely only via Tailscale serve or SSH tunnel)
- 14322 transparent MITM forward proxy (CONNECT for https, absolute-form for http)

## Install
- Releases carry build-provenance attestations. `gh attestation verify` needs a recent gh (the distro's gh may be years old); fetch current gh from cli/cli releases and checksum-match it first. Fallback while debugging: `gh api /repos/Infisical/agent-vault/attestations/sha256:<digest>` proves bundle existence, not validity.
- `gh attestation verify <tar> --repo Infisical/agent-vault --format json` prints the verified subject list — confirm your exact artifact digest is in `statement.subject`.
- Server: `AGENT_VAULT_TELEMETRY=0 agent-vault server --host 127.0.0.1 --port 14321 --mitm-port 14322 --password-stdin` (foreground for systemd; `-d` daemonizes).

## Bootstrap flow (all doable via CLI, no web UI needed)
```
agent-vault auth register --address http://127.0.0.1:14321 --email <owner> --password-stdin
agent-vault vault create <name> && agent-vault vault use <name>
agent-vault vault credential set 'KEY=value'          # NEVER argv for real values — UI/stdin only
agent-vault vault service add --name openrouter --host openrouter.ai:443 --auth-type bearer --token-key OPENROUTER_API_KEY
agent-vault agent create <agent> --vault <name>:proxy --token-only
```
- Auth types: bearer, basic, api-key (custom header), custom (freeform `{{ KEY }}` templates), passthrough (allowlist, no injection).
- Host matcher: bare host, one-level wildcard (`*.github.com`), path glob (`slack.com/api/*`), port-scoped (`host:443`). No port in the rule = matches ANY port — pin ports for production rules.
- A one-level wildcard does NOT match the bare apex: `*.github.com` covers `api.github.com` but 403s `github.com` itself — apex hosts need their own explicit rule.
- Allowlist entries must include documented redirect targets: an allowlisted host that 301s to a non-allowlisted domain (e.g. a project host redirecting to its github.io page) 403s mid-chain and breaks the flow silently. Add the target host as its own rule.

## Vault settings via management API (no CLI command exists)
```
curl -c cookies -X POST -d '{"email":...,"password":...}' http://127.0.0.1:14321/v1/auth/login
curl -b cookies -X PATCH -H 'Content-Type: application/json' -d '{"unmatched_host_policy":"deny"}' http://127.0.0.1:14321/v1/vaults/<name>/settings
```
- Default `passthrough` forwards unmatched hosts; `deny` returns 403 + proposal hint. Agent tokens can READ settings but mutation requires vault admin/owner (verified boundary).

## Agent-side wiring (what `vault run` sets on the child)
- `HTTPS_PROXY`/`HTTP_PROXY` = `http://<token>:<vault>@<host>:14322`, `NO_PROXY=localhost,127.0.0.1`, `NODE_USE_ENV_PROXY=1`
- CA trust: `SSL_CERT_FILE`, `NODE_EXTRA_CA_CERTS`, `REQUESTS_CA_BUNDLE`, `CURL_CA_BUNDLE`, `GIT_SSL_CAINFO`, `DENO_CERT` → fetched CA (`agent-vault ca fetch`); contains ONLY the vault root CA.
- git's libcurl IGNORES `SSL_CERT_FILE` and `CURL_CA_BUNDLE` — git CLI operations behind the MITM need `GIT_SSL_CAINFO=<ca.pem>` (env or `git config http.sslCAInfo`), else they fail with "certificate signer not trusted" even when every other client works.
- Agent mode (unattended): `AGENT_VAULT_TOKEN` + `AGENT_VAULT_ADDR` + `AGENT_VAULT_VAULT` env before `vault run`.
- Token lifecycle: `agent rotate`, `agent revoke`; agents hold a `proxy` vault role: cannot read/set credentials or mutate services; CAN list credential key NAMES (metadata leak, accepted); can raise proposals for new services (human approves).

## Substitutions (for URL/query/body-embedded credentials)
Service YAML `substitutions:` block: `key` (credential), `placeholder` (wire literal, `__name__` convention), `in:` surfaces (`path`, `query`, `header`, `body`, `websocket` — only declared surfaces are scanned). Covers credentials that live in URL paths (e.g. bot tokens) — a later-phase alternative to leaving them in agent env.

## Netguard (verified)
Blocks RFC1918, loopback, link-local, CGNAT 100.64/10, 0.0.0.0/8, cloud metadata (169.254.169.254) even when allowlisted, IPv6 loopback/ULA/link-local and v4-mapped forms, plus DNS-rebinding (policy applies to resolved IP, not hostname). All return 502 through the proxy.

## Master password
- `master-password change` requires a TTY (no stdin flag) — for unattended rotation on an EMPTY vault, wipe the data dir and restart with a fresh password instead.
- Losing the master password = data unrecoverable. Root should back up `/etc/agent-vault/master` (0600) to a password manager.

## HTTP behavior notes (verified)
- MITM terminates the client leg: HTTP/2 downgrades to HTTP/1.1; request smuggling between agent and origin is structurally eliminated (proxy re-originates upstream requests).
- Streaming, chunked responses, SSE-equivalent long-lived streams, 1 MiB+ bodies, and concurrent requests all work through the proxy.
