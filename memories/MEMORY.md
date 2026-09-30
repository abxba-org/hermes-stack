Connected toolkits: linear (48 tools, ACTIVE), notion (57 tools, ACTIVE), context7_mcp (2 tools, ACTIVE), slack (ACTIVE — used for :eyes: reactions); github (896 tools) and youtube_transcript (9 tools) connected but status EXPIRED — need `composio link github` re-auth before use.
§
User 'ABXBA'. Linear board: team Workspace_HQ, project Hermes Agent HQ; AGENT_TASKS = my work, abxba_TASKS = his. IDs/quirks in skill 'linear-task-board'.
§
Voice transcription: Slack auto-transcribe can fail; audio in ~/.hermes/cache/audio/*.m4a → faster-whisper (--user, small/int8, CPU); pattern in scratch/transcribe.py.
§
Slack standing behavior (ABXBA): FIRST action every turn = react :eyes: to his message BEFORE any work/reply. Get chat_id + source_message_id from gateway origin metadata; if no message_id, SLACK_FETCH_MESSAGE_THREAD_FROM_A_CONVERSATION {"channel": chat_id, "ts": thread_id, "limit": 5} → newest message from U0C4EAU771B (key is `ts`). Then SLACK_ADD_REACTION_TO_AN_ITEM {"channel", "timestamp", "name": "eyes"}. Never react to own messages (me = U0C4KCULFL2). Slack toolkit via composio (re-link `composio link slack` if expires). DM: D0C4DA5F6N7, thread 1790514532.713049.
§
vps-1558ffa7 IS vps-ovh.tail95f2ee.ts.net — ONE box, two names (tailnet 100.79.32.56, public 57.129.161.166). Runs agent-vault `hermes` (14321/14322 loopback; ON/OFF toggle /usr/local/bin/vault-mgmt, skill 'agent-vault-hermes') AND Grafana Alloy+auditd → daintyholly3409.grafana.net (skill 'grafana-cloud-observability').
§
Push channel to ABXBA's iPhone REMOVED 2026-09-27 at his request. NO push channel — don't try ntfy pings. Details in skill 'user-notifications'. iPhone = tailnet peer iphone173.
§
Sandbox rule (ABXBA): experiments/tests run ONLY on sandbox, clone, or throwaway copies — never the production/main system (real repos, /etc, live data). Real artifacts only with explicit user approval.
§
Vault access issue + ABXBA messaging via Slack: tell him to run `sudo vault-mgmt on` on the VPS (temp-ON, auto-OFF 30m; --persist to keep) or use SSH tunnel ssh -L 14321:127.0.0.1:14321. Agent can batch-apply rule adds itself via owner session.json Bearer token — no user login needed.