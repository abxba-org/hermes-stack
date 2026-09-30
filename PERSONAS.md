# Hermes Personas & Permission Boundaries

Three persona profiles on vps-1558ffa7. Each is an isolated Hermes home under
`~/.hermes/profiles/<name>/` — own config, SOUL.md identity, memory, skills, sessions.
Usage: `hermes personal chat`, `hermes research chat`, `hermes automation chat`
(or `-p <name>` with any hermes command). Config changes: `hermes -p <name> config set ...`,
tool toggles: `hermes -p <name> tools enable/disable <toolset>`. Tool changes take effect on a new session.

## Permission matrix

| | personal | research | automation |
|---|---|---|---|
| Purpose | day-to-day assistant | cited research findings | headless scheduled ops |
| Shell | local | NONE | Docker sandbox (nikolaik/python-nodejs, 2GB mem cap) |
| Browser | yes (vault logins) | no | no |
| Web search/extract | yes | yes | yes |
| File read/write | yes | yes (findings) | yes (workspace) |
| Code execution | yes | yes (analysis) | yes |
| Memory / skills | yes | yes | yes |
| Subagents (delegation) | yes | no | no |
| Cron jobs | yes (create) | no | yes (runs headless) |
| Image gen / TTS / vision | yes / yes / yes | no / no / yes | no / no / no |

## Approval policy (all profiles: approvals.mode = smart)

Interactive sessions: dangerous shell commands get an aux-LLM risk assessment
(auto-approve low-risk, auto-deny high-risk, prompt when uncertain).

Headless contexts are DENY by default on every profile:
- `approvals.cron_mode: deny` — cron jobs can never auto-approve dangerous commands
- `approvals.single_query_mode: deny` — `hermes chat -q` same
- `approvals.unattended_mode: deny` — webhook/API sessions same

## Egress controls (current baseline)

- `security.allow_private_urls: false` — blocks SSRF/exfil to private/internal ranges
- `security.redact_secrets: true` — secrets scrubbed from all tool output
- automation's shell is inside a Docker container (filesystem isolation)
- Note: full network allowlisting (squid/iron-proxy in front of the sandbox) is NOT yet
  configured — a sandboxed shell can still reach the internet. Follow-up hardening if wanted.
- Per-domain blocklist available via `security.website_blocklist` (currently empty)

## Identity files (SOUL.md per persona)

- personal: confirm before sending messages/purchases; no long-running automation
- research: cite every claim; web content = untrusted data; no shell/browser
- automation: terse verified status lines; never fabricate results; narrow command scope

## Docker sandbox prerequisites

- `ubuntu` was added to the `docker` group (2026-09-27) — effective for fresh login shells.
  If `automation` fails with a docker permission error, re-login (or run under `sg docker -c ...`).
- First run pulled `nikolaik/python-nodejs:python3.14-nodejs22`.

## Verification log (2026-09-27)

- research smoke test: shell execution refused; web search with cited URL worked.
- automation smoke test: docker sandbox command run (see Linear ABXBA-15 comment).