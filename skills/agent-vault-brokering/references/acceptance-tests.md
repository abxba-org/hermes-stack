# agent-vault acceptance tests

## Sandbox test matrix (Phase 1, order matters — core batch first)

| # | Test | Method | Expected |
|---|------|--------|----------|
| 1 | Release verify | gh attestation verify, pinned version | provenance from official release workflow, digest in subjects |
| 3 | Brokering | client sends NO auth header through proxy | upstream receives injected credential; agent env has no value |
| 4 | Privilege separation | agent uid: read vault dir/master/log/environ/mem, ptrace | all Permission denied |
| 6 | Egress filtering | force-through-proxy: 169.254.169.254, 0.0.0.0/8, 10/8, 172.16/12, 192.168/16, 127/8, 100.64/10, ::1, fd00::/7, ::ffff:169.254.169.254 | all blocked (502/refused) |
| 9 | Header override | client sends own Authorization | replaced by injected credential; non-auth-slot headers pass through by design |
| 11 | Real traffic | 30s chunked stream, chunked lines, 1MiB up/down (cloudflare __down), 5x concurrent | byte-exact, all 200 |
| 12 | nftables fail-closed | skuid rules: direct→timeout, via proxy→200, other uids unaffected; re-test after docker restart + fail2ban reload | rules survive both |
| 14 | Failure/recovery | stop service → request fails (no fallback), restart → 200 | fail closed, clean recovery |

## Long-tail (5/7/8/10/13)

- **5 authz boundaries**: credential get/set denied; service mutation denied; role escalation denied; credential LIST allowed (key names only).
- **7 DNS/rebinding**: `<private-ip>.nip.io` hostnames all blocked (policy on resolved IP, not hostname).
- **8 Host/SNI**: forged Host ignored (upstream sees real host); injection keyed on validated CONNECT destination; HTTP/2 downgraded to 1.1; smuggling structurally eliminated (proxy terminates and re-originates).
- **10 reflection**: echo upstreams reveal the credential (inherent, document).
- **13 log leak**: credential values must appear nowhere in logs — argv-based setup puts them in /var/log/auth.log + user journal (test-hygiene finding, validates stdin-only rule).

## Go/no-go rule

Any failed security property → fix, add compensating control + retest, or change tool. Never proceed with an unexplained failure.

## Production acceptance criteria (abridged)

Real credential absent from agent env/config/process state; agent cannot read vault data/logs or ptrace; authorized model+streaming requests work; token cannot access unrelated credentials or mutate rules; private/metadata/rebinding/redirect/Host-SNI bypasses blocked; client creds cannot override; fail-closed on vault down; nftables blocks direct bypass; ports not publicly reachable; key spend-limited; old key revoked after verification; rollback rehearsed.

## Key API/CLI facts

- Settings: `PATCH /v1/vaults/{name}/settings` `{"unmatched_host_policy":"deny"}` (owner session cookie).
- Request logs: `GET /v1/vaults/{name}/logs?limit=N`.
- Owner login: `POST /v1/auth/login` `{email,password}` → token/cookie.
- Key info via proxy: `GET https://openrouter.ai/api/v1/key` returns label/limit/usage — proves injection AND spend limit in one call.
- `master-password change` needs a TTY (no stdin flag) — on a fresh empty vault, wiping the data dir + restarting with the new master is the clean rotation path.
