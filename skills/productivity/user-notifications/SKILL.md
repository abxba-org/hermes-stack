---
name: user-notifications
description: Use when notifying ABXBA outside Slack (no Slack notifs).
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [notifications, voice]
    related_skills: [local-service-ops, hermes-agent]
---

# Notifying ABXBA

## When to Use

Use this skill whenever a message needs to REACH ABXBA on his phone with certainty — finished-work pings, urgent alerts, decisions waiting on him — or when setting up, restarting, or extending his communication channels (push, voice, SMS, calls). Do not rely on Slack delivery for anything time-sensitive.

## Always-on rules

- ABXBA does not reliably receive Slack notifications, so time-sensitive pings need a push channel. The self-hosted ntfy server (tailnet-only) was REMOVED at his request on 2026-09-27 — there is currently NO push channel; don't try to call ntfy_send.sh or the removed daemon. When asked to notify him outside Slack, report the gap and offer to set up a replacement (self-hosted + tailnet-only preferred).
- When a push channel is (re)built, keep: short actionable text, priority discipline (3 default, 4 needs-decision, 5 only genuine urgency), and topic/credential secrecy.
- He cares about the security/privacy of communication channels. Prefer self-hosted + tailnet-only over third-party endpoints by default; say so explicitly when proposing a new channel.

## Other mediums (build when asked, not by default)

- Voice/SMS/call options with verified pricing and latency tradeoffs: `references/live-call-media.md`.
- Slack voice messages: text_to_speech tool sends a native voice bubble in this DM — zero setup, works today. Use when he asks to "hear" an answer.
- Telegram: NOT viable for calls (Bot API has no calling); viable only as a free push/voice-note channel.
