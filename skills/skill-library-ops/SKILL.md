---
name: skill-library-ops
description: Inventory the skill library and publish it to git repos.
version: 0.1.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [skills, inventory, backup, github, publishing]
    related_skills: []
---

# Skill Library Ops

Inventory `~/.hermes/skills/` (which skills are custom vs pre-built) and
publish or back the library up to a git repo. Covers the library itself, not
authoring skill content (see `hermes-agent-skill-authoring`) or general gh
workflows (see `github`).

## When to Use

- "Which skills did you make for me / which are custom vs stock?"
- User wants the skill library (or a subset) backed up or published to a git repo.
- Periodic sync/backup of `~/.hermes/skills/` after new skills were authored.
- Don't use for: writing or editing skill content, or ordinary gh PR/issue work.

## Library layout

- Active skills: `~/.hermes/skills/<category>/<name>/SKILL.md` (plus optional `references/`, `templates/`, `scripts/` subdirs — copy whole skill dirs, not just SKILL.md).
- Plugin skills: `~/.hermes/plugins/<plugin>/skills/`. Optional shipped catalog: `~/.hermes/hermes-agent/optional-skills/`. Neither is part of the user's custom set.
- `~/.hermes/skills` has NO git history — never look for commits to distinguish origins.

## Procedure 1: inventory custom vs pre-built

1. List every SKILL.md with its mtime:
   `find ~/.hermes/skills -name SKILL.md | xargs -I{} stat -c "%y {}"`
2. Skills sharing ONE identical timestamp (to the second) = the pre-built install bundle. Anything later = touched after install.
3. Separate authored from merely edited: grep the post-install skills for user-specific infrastructure (the user's hostnames, tailnet names, org/user handles, project names). Matches = custom-authored for this user; clean = pre-built skill that was only patched.
4. State the confidence limits in the answer: a rewrite resets BOTH mtime and birth time (files are replaced atomically on edit), so timestamps prove pre-built vs post-install only — the content grep is what carries the authored-vs-edited call. Say so instead of presenting the split as proven fact.

## Procedure 2: publish skills to a GitHub repo

1. Confirm with the user BEFORE pushing: target repo (create new vs existing, org vs personal), visibility, and whether to secret-scan. Do not pick a repo target unilaterally — the org may have a natural home (e.g. an existing config-backup repo) only the user knows about.
2. Use the `gh` CLI, not Composio, for git operations — the Composio github connection has been expired while `gh` stays authed; check `gh auth status` and `gh api user/orgs` first to get the account and org names.
3. Stage a COPY in the scratch dir (`~/.hermes/cache/scratch/<repo>-stage/`), never push from `~/.hermes/skills/` directly. The copy lets you scan and prune before anything leaves the machine and keeps the live library untouched.
4. Secret-scan the staged copy (patterns in `references/secret-scan.md`). Every hit that is a `<token>`-style placeholder or prose ABOUT where secrets live is safe; only literal key material blocks the push. Hostnames/IDs are fine for a private repo — confirm visibility with the user.
5. Push:
   ```
   gh repo create <org>/<name> --private --description "..."
   git init -q -b main && git add -A && git commit -m "..."
   git remote add origin https://github.com/<org>/<name>.git && git push -q -u origin main
   ```
6. Verify the push by reading the remote back — `gh api repos/<org>/<name>/git/trees/main?recursive=1` file count must match the staged file count, and list the top-level dirs. A successful `git push` exit code alone is not verification.

## Pitfalls

- Copy whole skill directories including `references/`/`templates/` — a SKILL.md-only export loses the depth files the skill depends on.
- `gh repo create` takes the FULL `org/name` slug; a bare name creates under the personal account.
- Recursive-delete staging cleanup and bulk `cp` loops trip command-approval security scans — keep the staging commands plain and expect the user to approve the initial `rm -rf` of a scratch dir.
