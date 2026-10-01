---
name: agent-tooling
description: Use when installing external agent tools or MCP servers.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [tools, mcp, installation, uv, skillspector]
    related_skills: [hermes-agent, skillspector]
---

# Agent tooling integration

## When to Use

Use when installing an external agent tool (security scanner, CLI utility) onto this machine, or registering/wiring an MCP server into Hermes config. Not for Hermes plugins (see hermes-plugins) or Composio capabilities (see composio-tools).

Procedure for adding an external agent tool: install it isolated, register it, verify it actually works end-to-end, then report. Static-only security scanning of skills is covered by the user-owned `skillspector` skill; this skill carries the install/verify machinery.

## 1. Install

Prefer `uv tool install` — isolated venv per tool, no system packages.

- `uv` not present: `python3 -m pip install --user uv` (the astral.sh installer URL returns 403 from this box).
- Native-extension pitfall: if the latest Python has no prebuilt wheel for a native dep (e.g. yara-python), the build demands a C compiler and fails. Pin an older interpreter to get wheels instead of installing compilers: `uv tool install --python 3.12 '<pkg> @ git+<repo-url>'`.
- GitHub git+ URLs of tools can take minutes; run with a generous timeout.

## 2. Register an MCP server in Hermes

```
hermes config set mcp_servers.<name>.command /abs/path/to/binary
hermes config set mcp_servers.<name>.args '["subcommand"]'   # value is a JSON/YAML list as a string
hermes config get mcp_servers    # read back to confirm
```

- Use absolute paths — the MCP subprocess env is filtered to a safe baseline, so PATH-only lookup of a tool in `~/.local/bin` may fail.
- Use `hermes config set`, never hand-edit `~/.hermes/config.yaml`.
- Tools register as `mcp_<server>_<tool>` after an agent restart; discovery happens at startup only.

## 3. Verify before claiming done

A registered-but-unverified MCP server is an untested claim. Run the handshake + a real tool call with `scripts/mcp_handshake_test.py` (edit the command/args/tool-name constants) — it initializes the session, lists tools, and round-trips one call.

- Run it via terminal, NOT from a code-kernel: the kernel's captured stdio cannot spawn subprocesses. Use an interpreter that has the `mcp` package — the tool's own uv venv (`~/.local/share/uv/tools/<pkg>/bin/python`) usually does.
- Check the tool's input schema from `list_tools()` output; parameter names are the server's (e.g. `target`, not `path`) — a wrong arg name is a pydantic validation error, not a missing tool.

## 4. Report

State: what's installed where, what's registered in config, what was verified by actual execution, and what requires an agent restart to take effect.

See `references/skillspector-ops.md` for the SkillSpector installation and scan-output specifics.
