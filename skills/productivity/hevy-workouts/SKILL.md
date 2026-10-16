---
name: hevy-workouts
description: Use when working with the Hevy API or ~/HEVY scripts.
tags: [hevy, fitness, slack, api]
---

# Hevy Workouts (~/HEVY)

## Verified API facts (live-tested 2026-10-13, account had 53 workouts)
- `GET /v1/workouts?page=N&pageSize=S` → `{page, page_count, workouts: [...]}`; max pageSize = 10 (400 otherwise); page beyond page_count → 404 `{"error":"Page not found"}` — pagination must treat 404 as stop, not error.
- `GET /v1/workouts/count` → `{"workout_count": int}`.
- `GET /v1/workouts/{id}` → workout object directly, NOT wrapped in `{"workout": ...}`.
- `GET /v1/workouts/events?since=<ISO>&page&pageSize` → newest-first; non-empty pages use key `events`, EMPTY response uses key `workouts` (quirk!). Event types seen: `updated` only; each event carries the full workout object.
- 401 returns an empty body; 400 errors use `{"error": "..."}`.
- workout.start_time is ISO8601 with +00:00 (sometimes fractional seconds + Z in events).

## Files
- `hevy_workouts.py` — GET-only fetch CLI (all/range/day), reviewed + null-checked; `get_if_exists()` treats 404 as None.
- `hevy_watch.py` — new-workout watcher → Slack summary. State in `watch_state.json` (last_run + seen ids); state written only AFTER successful Slack posts (crash-safe retry). Commands: `--bootstrap` (baseline, no posts), `--dry-run`, `--status`, `--tz +05:30` (ABXBA's local tz).
- `hevy_analysis.py` — pure analysis functions (no network/I/O): e1RM (Epley), `match_previous` (matches prior session by exercise template ID overlap, NOT title — his titles vary: 'Upper' vs 'Upper Body'; requires ≥2 shared, strictly earlier), `detect_prs` (today's best e1RM > all-time best, epsilon 0.05 kg; ties are NOT PRs), `detect_struggles` (rule order: same-weight rep loss → e1RM regression → in-set rep drop-off ≥40% → RPE ≥9.5 grinders), `detect_focus` (skipped exercises + two-session regression), `format_detailed`. Message sections: totals + % volume delta vs matched prev session, PRs, Struggled, Focus next session.
- Slack delivery shells out to `/home/ubuntu/.local/bin/composio execute SLACK_CHAT_POST_MESSAGE` (channel D0C4DA5F6N7). Composio CLI is already authenticated globally.
- Cron: user crontab `0 */12 * * *`, sources `~/HEVY/.hevy_env` (0600, contains `export HEVY_API_KEY=...` — must be `export`, plain assignment is not inherited by python). Cron python = `/usr/bin/python3` (has requests).

## Gotchas
- First-ever run of the watcher MUST be `--bootstrap`, else it would Slack-spam every historical workout.
- Manual trigger = just run `hevy_watch.py`; it shares state with cron so no double posts.
- Vault note: api.hevyapp.com is in the vault service inventory (passthrough, name api-hevyapp-com); HEVY_API_KEY credential exists in vault hermes too — the script reads the key from env, vault is backup.
- Hevy also offers a webhook (POST on new workout) — ABXBA chose polling (12h + manual) over a public endpoint; receiver/Slack-relay design was deferred.
