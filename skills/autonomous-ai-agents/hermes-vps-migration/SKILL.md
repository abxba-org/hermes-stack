---
name: hermes-vps-migration
description: "Use when migrating Hermes to a new VPS or its backup repo."
version: 1.0.0
author: Hermes Agent + Teknium
license: MIT
metadata:
  hermes:
    tags: [hermes, migration, backup, vps]
    related_skills: [hermes-agent, agent-vault-hermes]
---

# Hermes VPS Migration & Config Backup

## When to Use

Load when: the user announces a VPS move or asks what Hermes data transfers;
building/extending the config backup repo; auditing secrets before
decommissioning a box; or diagnosing a stalled Hermes cron backup job.

Class-level workflow for: moving Hermes Agent to a new VPS, producing or
extending a migration/backup repo, and inventorying what is transferable vs
what must be re-entered manually. The user runs multiple self-hosted services
on one box (agent-vault, Grafana Alloy, restic, tailscale, HEVY) — a migration
audit always covers those too, not just ~/.hermes.

## Discovery first — always inventory before building

Before creating any backup or migration repo, check for prior infrastructure;
an earlier session may have built it. Extending beats duplicating:

1. `ls ~/.hermes-git/` — the backup working tree lives at
   `~/.hermes-git/hermes-config` (a COPY of config, not symlinks) with
   `backup-sync.sh` (whitelist copy -> secret-scan gate -> commit -> push).
2. `hermes cron list` — existing backup jobs (interval, deliver target, last run).
3. `git -C ~/.hermes-git/hermes-config remote -v` and `gh repo view <owner>/<name> --json visibility`.
4. `crontab -l` and `systemctl list-units | grep -iE 'hermes|alloy|vault'` — non-Hermes services that also need migration notes.

When an existing job exists, repoint its interval/schedule rather than adding a
parallel job — two jobs pushing to the same repo race and duplicate.

## What transfers vs what does not (verified inventory)

Full table in `references/secrets-inventory.md`. Shape of the split:

- TRANSFERS via repo: config.yaml, SOUL.md, PERSONAS.md, skills/, plugins/,
  memories/, profiles/, cron/ (job defs), scripts/, slack-manifest.json,
  channel_directory.json, av-ca.pem (public CA cert — safe to track).
- NOT in repo BY DESIGN (secrets): ~/.hermes/.env, auth.json, the agent-vault
  service data, HEVY .hevy_env, restic password, gh/tailscale/composio logins.
- NOT transferred (runtime, regenerated): state.db + sessions/ (chat history),
  tools/ installs/ environments/ hermes-agent source (installer rebuilds),
  caches, gateway_state.json, pairing/, install_id.
- Separate git repos (e.g. project repos under ~) are referenced, never copied
  into the migration repo.

## Secrets inventory procedure

Enumerate key NAMES only — never print, quote, or store values, even in chat:

```bash
grep -oE '^[A-Z_0-9]+' ~/.hermes/.env          # .env key names
grep -oE 'export [A-Z_]+' ~/HEVY/.hevy_env     # env files use 'export KEY'
python3 - (walk auth.json printing only PATHS, not leaf values)
```

Then classify each as: re-enter manually / re-auth via login flow / re-mint on
new service instance. Flag any secret that is UNRECOVERABLE if lost (backup
encryption passwords) — those must be seeded into the agent vault before
any decommissioning.

## Backup-sync mechanics (pitfalls)

- The repo uses a whitelist .gitignore (`/*` then `!` entries). Adding a new
  top-level dir to the sync script does nothing until the dir is also
  un-ignored in .gitignore — commits silently exclude it otherwise.
- backup-sync.sh carries a credential-pattern gate that aborts BEFORE
  commit/push. Test any whitelist/script change by running the script manually
  and reading ~/.hermes-git/sync.log — do not wire cron first and hope.
- Never run the sync as root; it refuses, and it must only ever read the live
  ~/.hermes (copy into the working tree), never write to it.

## Cron ticker stall (diagnosis)

`hermes cron list` can show a job 'Overdue N days' while hermes-gateway.service
is active. Diagnose: compare `cat ~/.hermes/cron/ticker_last_success` (epoch) to
`date -u` — if the ticker stopped advancing, editing the job will not help; the
fix is restarting the gateway service, then confirming next_run_at advances in
jobs.json.
