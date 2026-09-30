---
name: linear-task-board
description: Use when adding/updating tasks in ABXBA's Linear board.
---

# ABXBA's shared Linear task board

Standing convention from ABXBA's voice instruction (2026-09-26): Linear is the shared to-do list between Hermes and ABXBA. Access via `composio execute` CLI.

## Structure
- Team: **Workspace_HQ** `c3dfb570-5e6a-4d26-870b-728f16f2f2b0` (key ABXBA)
- Project: **Hermes Agent HQ** `bc077318-8b06-4929-9183-c0bff2db012c`
- Labels: `AGENT_TASKS` `516c2218-f654-42d6-8022-1b9fc9a083cf` = Hermes's own tracked work (repo, assigned tasks); `abxba_TASKS` `0e378b05-09f7-4e1f-a078-45236885e595` = tasks ABXBA sends via Slack/email, logged by Hermes with the timestamp he made it.
- States: Backlog `40f98085-ac96-4af2-9c44-aeba800ec9e5`, Todo `fda21027-e29f-4d03-a856-b5f8295bca8c`, In Progress `27d129d0-c561-4ef1-98e7-c81fc7cd6ffc`, Done `2043c7b8-bdff-48d3-86cf-6ad98331daa9`.
- Stale Linear onboarding issues ABXBA-1..4 are Canceled — ignore.

## Workflow
1. ABXBA sends a task (Slack now, email later) → create issue in Hermes Agent HQ, label `abxba_TASKS`, include exact request + source + timestamp.
2. Own work → label `AGENT_TASKS`. Track repo/assigned tasks there.
3. Report status back to ABXBA via Slack when a task changes state.

## Composio CLI syntax
- `composio execute TOOL -d '{json}'` — args go after `-d`, NEVER as a bare positional (positional JSON gives "unknown argument"). JS-style keys without quotes work: `-d '{issueId: "...", stateId: "..."}'`.
- Full tool dump cached at /tmp/composio_tools_linear.json (rebuild with `composio search "linear ..."` if missing).

## Composio Linear API quirks
- `LINEAR_CREATE_LINEAR_ISSUE` uses snake_case keys: `team_id`, `project_id`, `state_id`, `label_ids`, `title`, `description` (NOT camelCase). Returns `data.ticket_url`.
- `LINEAR_SEARCH_ISSUES` takes only `query`/`first`/`after`/`include_archived` — no team_id filter.
- `LINEAR_DELETE_LINEAR_ISSUE` takes `issue_id`.
- `LINEAR_UPDATE_ISSUE` uses camelCase: `issueId`, `stateId`, `labelIds` (NOT issue_id/state_id).
- `LINEAR_LIST_ISSUES_BY_TEAM_ID` uses `first` (not `limit`).
- `LINEAR_LIST_LINEAR_PROJECTS` takes only `after`/`first` — no team filter.
- `LINEAR_LIST_LINEAR_STATES` returns key `states`; `LIST_ISSUES_BY_TEAM_ID` returns `issues`; `LIST_LINEAR_LABELS` returns `labels`.
- Full tool dump cached at /tmp/composio_tools_linear.json.
- Get one issue with full description: `LINEAR_GET_LINEAR_ISSUE -d '{issue_id: "<uuid>"}'` (search by identifier first via LINEAR_SEARCH_ISSUES to get the uuid).
- `hermes profile describe <name> --text "..."` sets a profile's kanban-routing description (--description only exists at create time; positional arg fails).
