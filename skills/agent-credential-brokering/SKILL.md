---
name: agent-credential-brokering
description: "Use when deploying a credential proxy/vault for AI agents."
version: 1.0.0
author: hermes-agent
license: MIT
metadata:
  hermes:
    tags: [agent-vault, infisical, secrets, credential-proxy, nftables, systemd]
    related_skills: [hermes-agent]
---

# Agent Credential Brokering (agent-vault pattern)

Deploy a credential broker (Infisical agent-vault or equivalent) so AI agents never hold real secrets: the proxy injects credentials server-side on outbound HTTP. This skill assumes user ABXBA's standing rules: plan-first with explicit authorization gates, sandbox/throwaway before production, and user presence for anything that rewrites a privilege boundary.

## Procedure

1. **Research before planning.** Verify the product's actual integration modes against its docs before designing around one — e.g. base-URL mode may simply not exist even if it sounds natural. Check maturity (age, release cadence, license, open issues), install methods, and the security model. Distinguish verified facts from inference in the brief.
2. **Plan with hard gates.** Present the design in chat, get explicit approval per phase. Define scope exclusions explicitly (which credential types are NOT covered) and the threat model honestly — same-host deployments weaken the core guarantee; say so in the design, not after.
3. **Sandbox first, always.** Throwaway users/container, dummy credentials, ports offset from production. Run the test suite with core fail-closed properties FIRST (brokering, privilege separation, egress filtering, header override, real traffic, network enforcement, failure/recovery), long-tail attacks after. Any failed security property = fix, compensate, or change tool — never proceed unexplained. Produce a report with findings and compensating controls, then get a separate go/no-go.
4. **Production install.** Pin the release version; verify artifact provenance cryptographically before install (see `references/agent-vault-quick-ref.md` for the attestation procedure). Dedicated system user, hardened systemd unit (see templates/), secrets delivered via stdin from systemd LoadCredential. Pre-change backup of everything that contains the old credential, root-only 0600.
5. **Wire the agent, verify, then migrate privileges as a SEPARATE window.** Never combine wiring and user-migration changes in one debugging session. The migration runbook needs: rehearsal on a copy of the tree with timings, out-of-band access confirmed (provider console + admin SSH from a second device), verify + undo per step, and the user present.
6. **Firewall last.** nftables UID rules turn the proxy from convention into enforcement (see pitfall below).
7. **Revoke old credentials promptly after the restart checks come back clean** — no soak period. A burned key sitting in a live process environment is a standing liability; rollback mints a fresh temporary credential rather than resurrecting the revoked one.

## Pitfalls

- **Never pass credential values as CLI arguments** — sudo logs argv to auth.log and journald captures it. Enter credentials via the product's web UI or stdin, even for throwaway dummy values.
- **Verify a key was actually rotated with an equality test, not provider key-info endpoints** — fetch the vault credential as owner and compare (equality-only) against the backed-up old value. Provider `/key`-style endpoints return USER-AGGREGATE label/usage: two genuinely different keys report identical labels and shared ticking counters, so label/usage comparison both false-positives AND false-negatives.
- **`/proc/PID/environ` does not show dotenv-loaded variables** — env vars injected by the app at runtime are invisible there. An environ scan is necessary but never sufficient; network-level enforcement is the definitive direct-path closure.
- **`HTTPS_PROXY` is convention, not a security boundary** — the client can unset it. Enforce with nftables `skuid` rules in a DEDICATED table with explicit hook priority, arm a `systemd-run --on-active=…` auto-revert before applying anything, and re-test after a Docker restart and a fail2ban reload — both rewrite their own tables and can clobber edits made inside their chains.
- **Scope MITM CA trust to the agent process only** (`SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE`, `NODE_EXTRA_CA_CERTS`, `CURL_CA_BUNDLE`), never the system store. A bare curl failing TLS verification against the proxy is the expected fail-closed behavior, not a bug.
- **Strict deny is usually opt-in** — default proxy behavior forwards unmatched hosts. Set `unmatched_host_policy=deny` (vault-level setting) and verify unmatched requests 403.
- **Relocating a Hermes-style install breaks silently on venvs and launchers** — shebangs, `pyvenv.cfg`, and extension-less launcher scripts bake absolute home paths. Rewrite `/old/home/.hermes` across ALL text files (`grep -rl --binary-files=without-match` loop), not just configs; validate with a one-shot run as the migrated user.
- **systemd + `ProtectSystem=strict` needs `StateDirectory=`** (and the dir existing) or the unit dies with `status=226/NAMESPACE`.
- **`ProtectHome=true` on a unit whose runtime lives under /home fails at step EXEC with a bare ENOENT** — the mount namespace hides /home entirely, so the ExecStart path "does not exist" though it is on disk. Use `ProtectHome=false` + `ProtectSystem=strict` + `ReadWritePaths=/home/<user>` for home-resident runtimes, and create the user's home subdirs (e.g. `.local/bin`) owned by that user — root-owned 700 dirs silently break the app's self-install/launcher-publish steps.
- **Deliver the master password via stdin** (`--password-stdin < $CREDENTIALS_DIRECTORY/...`) — an env-var route leaves the password readable in `/proc/PID/environ` for the process lifetime. If one ever lands in a transcript, treat it as burned: rotate and wipe any data encrypted under it.
- **`pkill -f PATTERN` matches your own shell when the command string contains the pattern** — kill by `-u user` or exact process name.
- **Upstream test-server quirks masquerade as proxy bugs** — httpbin caps `/bytes` at 100 KiB and `/stream` at 100 lines; verify large-transfer behavior against a second endpoint before blaming the proxy.
- **The broker only owns its auth slot** — client-supplied credentials in the injected header position are replaced, but every other header passes through, and an upstream that echoes auth headers reveals the injected credential to the agent. Passthrough service rules are deliberate data-egress paths; note them in the threat model.

See `references/agent-vault-quick-ref.md` for verified commands and endpoints, and `templates/` for the validated systemd unit and credential wrapper.