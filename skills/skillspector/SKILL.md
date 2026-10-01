---
name: skillspector
description: Scan agent skills for security risks with SkillSpector BEFORE installing or trusting them. Use when adding any new skill, plugin skill, or MCP server config to Hermes.
version: 1.0.0
metadata:
  hermes:
    tags: [security, skills, vetting]
---

# SkillSpector — skill security gate

Standing rule: **no skill gets installed into the skills directory (or trusted/run) without a passing SkillSpector scan.** NVIDIA research found 26% of marketplace skills contain vulnerabilities, 5% likely malicious.

## Tools available

1. **MCP tool** (preferred, when connected): `mcp_skillspector_scan_skill` — params: `target` (path/URL/zip/dir), `use_llm` (always false), `output_format` (`json`).
2. **CLI**: `/home/ubuntu/.local/bin/skillspector scan <target> --no-llm --format json --output /tmp/report.json`
   - Installed via `uv tool install --python 3.12 'skillspector[mcp] @ git+https://github.com/NVIDIA/skillspector.git'`.
   - Update with: `PATH="$HOME/.local/bin:$PATH" uv tool upgrade skillspector`

Both are static-only. Never pass `use_llm: true` or omit `--no-llm` without explicit user approval — LLM mode sends skill file contents to an external provider.

## Workflow for a new skill (before install)

1. Obtain the skill (clone/zip/dir) into scratch, never directly into `~/.hermes/skills/`.
2. Scan it. Check the JSON report:
   - `risk_assessment.score` (0–100), `.severity`, `.recommendation`
   - `issues[]` — read every HIGH finding in full; note file + line
3. Gate on the verdict:
   - CLEAN / LOW (score < 20, no HIGH/MEDIUM findings) → proceed with install.
   - MEDIUM / CAUTION → present the findings to the user, install only after approval.
   - HIGH score or any CRITICAL / REJECT → do not install; report the evidence to the user.
4. After approval, move the skill into place and record the scan in the report notes.

Also scan **MCP server configs** added to `config.yaml` (`skillspector scan <repo-or-dir-of-server> --no-llm`).

## Reading the report

- `filtered_findings` / `issues`: severity, rule_id, message.
- `analysis_completeness.is_complete` must be true — a partial scan is not a pass.
- False positives from known-good code: `skillspector baseline <dir> -o .skillspector-baseline.yaml`, then re-scan with `--baseline`. Baselines exclude accepted findings from the score.

## Baseline of installed skills

First full baseline recorded at `~/.hermes/cache/skillspector/baseline-<date>.json` (scores per skill). To re-check the installed set for drift, re-scan each skill dir and diff against that file; new findings in existing skills are as important as bad new skills.
