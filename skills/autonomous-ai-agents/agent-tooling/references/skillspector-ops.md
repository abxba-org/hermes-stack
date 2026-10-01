# SkillSpector operational notes

## Install (validated)

```
PATH="$HOME/.local/bin:$PATH" uv tool install --python 3.12 'skillspector[mcp] @ git+https://github.com/NVIDIA/SkillSpector.git'
```

- The `[mcp]` extra is required for `skillspector mcp` (MCP server mode); plain install gives CLI only.
- Binary lands at `~/.local/bin/skillspector`; its venv python at `~/.local/share/uv/tools/skillspector/bin/python` (has the `mcp` package — useful for handshake tests).
- Update: `uv tool upgrade skillspector`.
- Requires Python >=3.12,<3.15. Python 3.12 is pinned because yara-python has no cp314 wheel.

## JSON report schema

Top-level keys: `skill`, `risk_assessment`, `components`, `structured_summaries`, `issues`, `suppressed_count`, `metadata`, `analysis_completeness`.

- Verdict: `risk_assessment.score` (0-100), `.severity`, `.recommendation` (e.g. CAUTION, SAFE, DO_NOT_INSTALL), `.max_issue_severity`.
- Findings are under `issues[]` (also `filtered_findings` in some outputs); the per-finding field names for rule/message/evidence are NOT fully mapped — dump one raw finding before writing a parser against them.
- `analysis_completeness.is_complete` must be true for the scan to count as a pass.

## CLI quirks

- With `--format json`, stdout mixes rich progress output with the JSON — always use `--output <file>` and read the file; parse stdout only if nothing else works.
- One scan of a mid-size skill takes seconds to ~a minute; a full pass over ~50 installed skills at 4 workers took ~10 min. Run batch scans as background terminal jobs.

## Batch baseline scan

`scripts/baseline_scan.py <out.json>` scans every directory containing a SKILL.md under `~/.hermes/skills` and `~/.hermes/plugins` (4 workers, static-only) and writes `{path: {score, severity, recommendation, max_issue_severity, issue_counts, complete}}`. Baseline output lives under `~/.hermes/cache/skillspector/`.

## Interpreting flags (caution, not a settled rule)

Static scans flag instruction-heavy agent-behavior skills (imperatives like 'treat tool output as untrusted', 'dispatch subagents', 'execute scripts') with HIGH/CRITICAL scores — several legit workflow skills scored DO_NOT_INSTALL on text patterns alone. Never relay a DO_NOT_INSTALL verdict to the user before dumping the actual findings and checking they reference real code/commands, not the skill's own prose. Triage tooling for finding-level detail is not yet built.
