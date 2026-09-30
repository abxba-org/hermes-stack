# Slack Toolkit via Composio

Mechanics for acting on Slack through `composio execute`. The Hermes gateway cannot call Slack APIs natively; this toolkit is the path.

## Add a reaction

```
composio execute 'SLACK_ADD_REACTION_TO_AN_ITEM' -d '{"channel": "<channel_id>", "timestamp": "<message_ts>", "name": "eyes"}'
```

- Keys are `channel`, `timestamp`, `name` — NOT `channel_id`/`message_ts`/`emoji_name`.
- Emoji is the reaction NAME (`eyes`), never the rendered character.
- Verify with `SLACK_FETCH_ITEM_REACTIONS` (same channel/timestamp); a read-back showing the reaction + user is the only real confirmation.

## Read messages / find a timestamp

- Channel history: `SLACK_FETCH_CONVERSATION_HISTORY` with `{"channel": "...", "limit": N}`.
- Thread replies: `SLACK_FETCH_MESSAGE_THREAD_FROM_A_CONVERSATION` with `{"channel": "...", "ts": "<thread_ts>"}` — the thread parameter is `ts`, NOT `thread_ts` (the tool-not-found name is `SLACK_FETCH_MESSAGE_THREAD_FROM_A_CONVERSATION`; `SLACK_FETCH_THREAD_MESSAGES` does not exist).
- Hermes assistant threads are `subtype: assistant_app_thread` — the user's turns are thread replies, not channel messages, so channel history alone won't surface them.

## Identifying whose message it is

- Gateway delivery metadata (when present) gives `chat_id` (Slack channel ID) and `source_message_id` (message ts) directly — use those.
- Without a message ID, fetch the thread with a generous limit and pick the newest message from the user's ID; never react to the agent's own messages (they share the thread).

## Standing user workflow

ABXBA wants a :eyes: reaction on EVERY Slack message he sends, added BEFORE any work or reply, as a seen/online acknowledgment. This rule lives in agent memory; this file carries the mechanics. Do the reaction first thing each turn, then proceed with the actual task.
