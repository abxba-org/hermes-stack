# Hermes migration: secret & state inventory (OVH VPS layout)

Enumerate key NAMES only during audits; values never enter chat or the repo.

## ~/.hermes/.env — secret keys (6)
| Key | Restore on new VPS |
|---|---|
| OPENROUTER_API_KEY | OpenRouter account / agent vault |
| SLACK_APP_TOKEN (xapp-) | Slack app admin → OAuth tokens |
| SLACK_BOT_TOKEN (xoxb-) | Slack app admin → OAuth tokens |
| AGENT_VAULT_ADDR | Points at new VPS's own vault endpoint (loopback 14321) |
| AGENT_VAULT_TOKEN | Re-mint on the new vault instance |
| AGENT_VAULT_VAULT | Re-set config value |

Remaining .env entries are non-secret settings (proxies, timeouts, CA paths,
debug flags) — re-typed since the whole file is excluded.

## auth.json
Structure: version, active_provider, credential_pool.openrouter (1 entry).
Re-auth via `hermes setup` / re-enter key.

## Agent vault (separate service, /home/hermes, ports 14321/14322)
Own data store + encryption keys + session.json bearer tokens. Migrate as a
whole service: data dir + agent-vault.service + /etc/av-hermes.nft + CA — or
re-seed from scratch. Most sensitive item; seed recovery copies of
unrecoverable secrets (restic password) here BEFORE decommissioning.

## Host-level secrets outside Hermes
| Secret | Location | Note |
|---|---|---|
| HEVY_API_KEY | ~/HEVY/.hevy_env (gitignored) | hevy.com/settings?developer |
| Restic repo password | ~/.restic_password | UNRECOVERABLE if lost |
| RESTIC_REPOSITORY + creds | ~/scripts/restic_backup.sh | script not in backup repo |
| GitHub credentials | gh CLI / git credential store | `gh auth login` |
| Tailscale node identity | tailscaled state | re-join tailnet |
| Composio toolkit auth | ~/.composio | re-link expired toolkits anyway |
| Grafana Alloy remote-write creds | /etc/default/alloy + its CONFIG_FILE target | daintyholly3409.grafana.net |
| SSH agent keys | ~/.ssh/agent | copy manually if wanted |

## Runtime state — do NOT migrate (regenerated/reinstalled)
state.db (30MB chat store), sessions/, state-snapshots/, kanban.db, pastes/,
images/, audio_cache/, terminal-sessions/, logs/, backups/; tools/ (1.7G),
installs/ (233M), environments/ (80M), lsp/, hermes-agent source (871M);
caches (models_dev_cache, provider_models_cache); gateway_state.json, pairing/,
processes.json, install_id.
