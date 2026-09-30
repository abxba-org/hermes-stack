# Live-call / voice media options (verified prices, for building when ABXBA asks)

Decision context: ABXBA's phone is a UK mobile (+44 7xxx). Goal considered Sept 2026: a medium to talk to him by voice, ideally with real phone calls. Nothing built yet beyond ntfy pings + Slack TTS voice notes.

## Verified pricing snapshot (per conversational minute unless noted)

- Twilio outbound voice: US $0.0140/min; **UK mobile $0.0305/min**, UK landline $0.0158/min. US local number $1.15/mo (UK number ~$3.50/mo + KYC).
- OpenRouter audio APIs (no realtime/WebSocket — request/response only): whisper-large-v3 STT $0.000008/sec (~$0.0005/min); gpt-4o-mini-tts ~$15/1M chars (~$0.015/min of speech); audio-in chat models exist.
- OpenAI Realtime API (NOT on OpenRouter — needs direct OpenAI key): gpt-realtime-2.1 $32/$64 per 1M audio in/out tokens; **mini variant $10/$20 ≈ $0.02/min** of live conversation, sub-second latency.
- Retell AI (managed voice agent): platform ~$0.07/min + telephony (US $0.015, **UK outbound $0.10/min** per their international table), number $2/mo; their default GPT-5.2 stack ~$0.23/min before telephony.
- Telegram: Bot API cannot place/receive calls. Discord bots CAN join voice channels but need user-session hacks to capture speech — fragile.
- Slack: no bot calling; TTS voice bubbles only.

## Decision table

| Want | Build | Cost profile |
|---|---|---|
| Real phone calls, natural latency | Twilio Media Streams → OpenAI gpt-realtime-mini → tunnel (cloudflared) to this box | ~$0.05/min UK mobile (~$3–7/mo casual) |
| Phone calls, minimum build cost | Retell direct REST (skip Composio) | ~$0.17–0.33/min UK — 3–6x pricier |
| Cheapest DIY voice loop | Twilio → whisper STT → OpenRouter LLM → TTS | ~$0.03/min but 2–4s walkie-talkie latency |
| Voice anywhere, zero telephony | Browser push-to-talk page (GPT Realtime) or Slack/Telegram voice notes | ~$0.02/min AI only |

## Pitfalls

- OpenRouter has no bidirectional realtime audio API. If the requirement is natural conversation latency, the OpenRouter STT→LLM→TTS loop is the wrong tool — use OpenAI Realtime directly.
- Twilio media streams need a public TLS (wss) endpoint — cloudflared is already installed on this host; a managed tunnel exists but its ingress is configured in the Cloudflare dashboard, not locally. Ephemeral trycloudflare URLs break phone-facing subscriptions — prefer a named tunnel.
- Always quote UK-mobile rates for ABXBA (his phone), not US rates — the difference is ~2x on Twilio and dominates the DIY cost estimate.
- DIY always wins on cost at personal volumes; managed platforms win on build time. State both when he asks 'which should we use'.
