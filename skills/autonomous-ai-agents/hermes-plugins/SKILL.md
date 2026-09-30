---
name: hermes-plugins
description: "Use when installing or verifying Hermes plugins."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [hermes, plugins, installation, security-scan, verification]
---

# Managing Third-Party Hermes Plugins

## When to Use

Use when: the user asks to install, enable, update, or evaluate a third-party Hermes plugin from a GitHub repo (`hermes plugins install ...`); a plugin install is blocked by the security scanner; or a freshly installed plugin seems inactive. For bundled plugins, built-in toolsets, or skill-hub installs (`hermes skills install`), see the hermes-agent skill instead.

Plugins install from GitHub repos with `hermes plugins install <owner>/<repo> --enable`. The `--enable` flag loads it into the running gateway immediately; without it the plugin installs but stays opt-in.

## Standing rules

- Assess BEFORE installing, and get explicit user confirmation for any third-party plugin. Present what the plugin adds, where it overlaps skills already installed, and its caveats — then ask. The user's standing workflow for new plugins is: usefulness assessment first, confirmation second, install last.
- Read the plugin README's install section for the specific harness before running the command. Plugins ship per-harness caveats and often a documented acceptance test — use THEIR test to verify, not a home-grown check.
- Never run `--force` past a security-scan block without inspecting the source and getting user confirmation. The scanner gate exists for unreviewed sources; overriding it is the user's call, not yours.

## Procedure

1. **Assess**: fetch the repo README (web_extract), identify what it provides, overlaps with existing skills, and harness-specific caveats. Report to the user; wait for confirmation.
2. **Install**: `hermes plugins install <owner>/<repo> --enable`.
3. **If the security scan blocks it** (community/non-catalog source, CAUTION verdict): do NOT force blindly. Clone the repo to scratch (`git clone --depth 1`) and inspect the real runtime surface before recommending `--force`:
   - For Hermes plugins that surface is `.hermes-plugin/`: `plugin.yaml` (declared hooks) and `__init__.py` (`register()` — what hooks/skills it registers and what code actually executes). Read it end-to-end; it is usually small.
   - Grep where each HIGH finding lives. Findings concentrated in `docs/`, `tests/`, and release notes are pattern-match false positives (design-doc shell snippets, dummy tokens like repeated-character strings) — the scanner does not distinguish shipped code from prose about code.
   - Verify each HIGH category against shipped code only. Real network calls, shell-outs, or persistence writes in the runtime module are the stop line.
4. **Handle install warnings as data, not verdicts** — two known cosmetic ones:
   - "doesn't contain plugin.yaml / may not be a valid Hermes plugin" fires on the flattened-layout check; a git-clone layout keeps the plugin manifest under `.hermes-plugin/`. Verify on disk.
   - "declares Node dependencies" fires on mere presence of `package.json` — check whether `dependencies` is actually non-empty.
5. **Verify the install**, in order:
   - `hermes plugins list` shows the plugin `enabled` with the expected version.
   - `__pycache__` inside the installed plugin dir means the gateway imported the module (weak but real signal).
   - Run the plugin's documented acceptance test through a fresh `hermes chat -q "..."` session. For workflow plugins, the acceptance test is behavioral (a specific prompt auto-triggers a named skill before doing the task) — confirm the trigger fires in the output.
6. **Warn about session staleness**: already-running sessions (including the gateway/Slack session you are in) keep their pre-install toolset and never receive a first-turn bootstrap retroactively. Fresh CLI sessions pick plugins up immediately; long-lived messaging sessions need a restart.

## Pitfalls

- Restart any session that should use the plugin — a plugin loaded mid-conversation does nothing for the current session's system prompt.
- Updating a plugin = re-running the same install command (it re-clones); check `hermes plugins list` for the version after.
- Plugin-registered skills are namespaced `pluginname:skill-name` via `skill_view`; if a namespaced lookup misses, the plugin README's fallback (direct file read) is authoritative.
- If a plugin ships opt-in telemetry and the user hasn't opted in, offer the documented disable env var at install time rather than leaving it on by default.
