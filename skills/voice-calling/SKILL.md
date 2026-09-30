---
name: voice-calling
description: Use when the user wants phone calls or voice messages.
---

# Voice calling (ABXBA)

## When to Use

Use when the user asks about calling his phone, wants voice messages / spoken audio in Slack, compares telephony providers (Twilio, Retell, Vapi), or asks to build a voice agent. Also when any task needs outbound call cost estimates for his number.

## Standing facts

- ABXBA's phone is a UK +44 mobile (London). NEVER quote US telephony rates as 'his cost' — compute for the destination country and number type (UK mobile vs landline differ ~2x).
- He prices 'cheap but good' models and thinks in **per-month totals**, not per-unit rates. Always build 2-3 usage scenarios (e.g. 10x3, 20x5, 60x5 min) and run the arithmetic in execute_code/terminal — never mental math — then present the table as bullets (Slack has no tables).
- Slack has no bot voice-call capability. What works in Slack today: `text_to_speech` renders as a voice bubble (on demand or via cron). Offer that first as the zero-setup option before any telephony build.

## Routing decision

1. **Voice message / spoken reply in Slack** → `text_to_speech` tool. Done. No accounts.
2. **Real phone calls, soon** → Retell AI direct REST API (their docs, not Composio) or the DIY stack (see references/costs-and-stack.md). Compare $/mo at his expected volume before he picks.
3. **Real phone calls, owned stack, lowest cost** → Twilio (call leg) + OpenRouter audio APIs (STT/LLM/TTS loop) on this machine with a TLS tunnel for the media WebSocket. ~$0.05/min to UK mobile vs Retell ~$0.17-0.33/min — DIY wins at any volume but has 2-4s turn latency.

## Pitfalls

- Composio's catalog advertises retellai/vapi call tools, but `composio connections list` shows NO connection for either — check it before planning anything around Composio calling, or you will promise a capability that needs new account setup.
- OpenRouter has audio APIs (TTS `/api/v1/audio/speech`, transcription `/api/v1/audio/transcriptions`, audio-in chat models) but **no realtime WebSocket voice API** — the loop is request/response, so a DIY agent speaks with 2-4s latency. Set that expectation up front; do not promise natural conversation.
- Twilio outbound rates vary by destination AND line type; to a UK mobile it is ~$0.0305/min, UK landline ~$0.0158/min, and surcharged/mobile-other zones run 10-20x. A US caller-ID number ($1.15/mo) is fine for outbound; a UK number is ~$3.50/mo plus KYC — don't buy one unless he asks to receive calls.
- Always price both sides separately: carrier leg (Twilio/Retell) vs AI stack (STT+TTS+LLM). They scale differently and the carrier leg usually dominates.
