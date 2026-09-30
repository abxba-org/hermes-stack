# Voice calling: verified costs and build plan

Fetched and verified 2026-09 from Twilio's GB pricing page, Retell's pricing + international rate table, and OpenRouter docs. Re-verify rates before quoting — voice pricing pages update.

## Verified unit rates

| Component | Rate |
|---|---|
| Twilio US local number (caller ID) | $1.15/mo |
| Twilio outbound → US | $0.0140/min |
| Twilio outbound → UK mobile | $0.0305/min |
| Twilio outbound → UK landline | $0.0158/min |
| Twilio UK surcharged zones | $0.2293-0.4730/min |
| OpenRouter STT whisper-large-v3 | $0.000008/sec (~$0.0005/min) |
| OpenRouter TTS gpt-4o-mini-tts | ~$15/1M chars (~$0.015/min speech) |
| OpenRouter flash-class LLM | ~$0.005/min of conversation |
| Retell platform (infra+voice+TTS, cheap LLM) | ~$0.07/min |
| Retell outbound → UK | +$0.10/min (docs international table) |
| Retell default GPT-5.2 stack | ~$0.23/min + telephony |
| Retell number | $2/mo |

## Monthly totals for UK mobile (number + all usage)

| Usage | DIY Twilio+OpenRouter | Retell cheap stack | Retell GPT-5.2 stack |
|---|---|---|---|
| 10 calls x 3 min (30 min) | $2.67 ($2.21 free-TTS) | $7.10 | $11.90 |
| 20 x 5 (100 min) | $6.20 ($4.70 free-TTS) | $19.00 | $35.00 |
| 60 x 5 (300 min) | $16.30 ($11.80 free-TTS) | $53.00 | $101.00 |

DIY ≈ $0.05/conversation-minute to UK mobile (~15c per 3-min call). Free TTS (edge-tts) drops the AI side to ~$0.005/min.

## DIY stack (Twilio + OpenRouter)

- Twilio number → outbound call → Twilio Media Streams WebSocket (mulaw 8k) → this machine over `wss://` — needs a public TLS tunnel (cloudflared or ngrok; Twilio rejects plain ws).
- Audio loop per turn: decode mulaw → OpenRouter `/audio/transcriptions` (whisper-large-v3) → OpenRouter chat completions (flash-class model, streaming) → OpenRouter `/audio/speech` (gpt-4o-mini-tts) → re-encode → back over the socket.
- Turn latency 2-4s (three sequential request/response hops). Walkie-talkie feel; state it before building.
- One-time: Twilio account + small opening deposit (~$20, spendable); trial credit exists.

## Retell direct (no Composio)

- Free Retell account → API key → buy/bind a Retell phone number → `POST createPhoneCall` with from_number/to_number → poll call details by ID.
- Handles telephony + sub-second natural voice; cost is the platform stack. Bring-your-own LLM lowers it; custom SIP telephony is free on their side.

## Zero-telephony option

- Slack voice bubbles via Hermes `text_to_speech` (works now, free).
- Or a browser push-to-talk page on this machine: OpenRouter STT→LLM→TTS in a loop. No carrier accounts at all.
