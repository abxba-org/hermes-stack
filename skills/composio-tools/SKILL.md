---
name: composio-tools
description: Use when a capability is missing; check Composio CLI first.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [composio, connectors, integrations, cli]
    related_skills: [github, notion]
---

# Composio Tools

## When to Use

- A task needs a connector capability (GitHub, Notion, Linear, YouTube transcripts, docs lookup) with no matching native skill or tool.
- Any Composio CLI operation: auth, tool discovery, or tool execution.
- Hermes `tool_search` returns nothing for a service you expect to exist.

Native skills and tools come first; when none fits, check Composio BEFORE asking the user.

## Always-on rules

- Before asking the user how to do a task with no matching skill, search Composio for a tool. Asking first wastes a round-trip the CLI can settle.
- Never kill a running `composio login` background process — it is polling for the user's browser approval and finishes on its own.
- Tool dumps are huge (GitHub alone has ~900 tools). List tools to a file and filter with Python; never print a full tool list into the conversation.

## 1. Check auth state

Run `composio whoami`. A response with `"email":null` is unauthenticated. Watch for the mismatch trap: if `composio login` says "You're already logged in" but API calls still fail with 401 "Invalid or revoked user API key", the stored key is stale — the CLI's local state lies. Fix by running `composio logout` first, then login again.

## 2. Log in (interactive, browser approval)

`composio login` waits for the user to approve a link in the browser, so it must run as a background PTY process — foreground it hangs.

1. Start it: `terminal(command='composio login', background=True, pty=True)`.
2. Read the fresh link from `~/.composio/pending-login-session.json` (fields `loginUrl`, `expiresAt` — links expire in ~10 minutes).
3. Give the user the loginUrl and wait; do not kill the process.
4. Confirm success via `composio whoami` (real email) or polling the background process for "Login successful".

## 3. Discover tools

- `composio connections list` — connected toolkits with ACTIVE/EXPIRED status (parse the JSON; the command prints usage banners around it).
- `composio tools list <slug> --limit 1000` — requires a toolkit slug argument; a bare `tools list` errors. Save output to a file and summarize counts.
- `composio search "<use case>"` — semantic search by task description (e.g. "send email"), no toolkit needed.
- EXPIRED connections pass `tools list` but fail at execute time — re-auth with `composio link <toolkit>` before relying on one.

## 4. Execute a tool

`composio execute "<TOOL_SLUG>" -d '{"param": "value"}'` — slug is uppercase (e.g. `LINEAR_GET_CURRENT_USER`); arguments are a JSON dict.

On `Input validation failed`, do NOT consult docs or re-guess from the API's parameter names: the error message itself lists the allowed top-level keys, and Composio's keys often differ from the upstream API (e.g. Slack reactions take `channel`/`timestamp`/`name`, not `channel_id`/`message_ts`/`emoji_name`). Retry immediately with the keys the error names.

## 5. Link a toolkit (OAuth)

`composio link <toolkit>` waits for browser approval, so it hangs a foreground call. Never run it bare:

1. `composio link <toolkit> --no-wait --no-browser` — prints JSON with `redirect_url` immediately and exits.
2. Give the user the `redirect_url` to authorize; the account lands as `ca_...` pending status.
3. Confirm with `composio execute '<TOOLKIT>_TEST_AUTH' -d '{}'` (e.g. `SLACK_TEST_AUTH`) — `"ok": true` means live. For unlinked toolkits, execute returns `ToolRouterV2_NoActiveConnection`.

Use `--list` to see existing accounts for a toolkit before creating a duplicate link.

Slack-specific depth (reactions, thread reads, finding a message timestamp): see references/slack-toolkit.md.

## Pitfalls

- Catalog gap: Composio tools do NOT appear in Hermes `tool_search` results. Discoverability is the CLI only — go straight to `composio search` rather than concluding a capability is unavailable.
- The CLI prints helpful-looking usage text alongside 401 errors, which can mask that the call actually failed. Parse for the `💥` error marker / exit code, not for the presence of output.
- `user_data.json` in ~/.composio may hold a masked/stale api_key while unauthenticated — file presence is not proof of auth; `whoami` is.
