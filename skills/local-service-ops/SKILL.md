---
name: local-service-ops
description: Check health of or uninstall self-hosted local services.
---

# Local Service Ops

## When to Use

- The user asks whether a self-hosted local app/service is "still working" or to check its status.
- The user asks to uninstall, tear down, or clean up a self-hosted local app — including "can it be uninstalled" (answer with a blast-radius report + go-ahead gate, don't delete yet).
- A local app's worker/runner component is in an error state and the user must decide between restart vs teardown.

Health-checks and teardown of self-hosted local apps (npm/npx-run control planes, embedded databases, agent runners). Default stance: verify with real probes, never infer state from memory.

## Health-check procedure ("is X still working?")

1. **Locate the app's footprint first.** Data/cred dirs (`~/.<app>/`, `~/.config/<app>/`), port, and process names. List key files before using them — credential files may be `.key`, not `.jwt`, and a wrong glob yields a 401 that looks like an expired token.
2. **Probe in layers, cheapest first:** process list (`ps aux | grep -iE "<app>|<embedded-db>"`) → port listen (`ss -tlnp | grep <port>`) → authenticated API call using the on-disk key. A dead API with live processes means the frontend died; live API with an agent/worker in error state means the app is up but a component is not.
3. **Parse responses from files, not pipes.** Write `curl -o /tmp/x.json`, then parse with a separate python3 step. Piping `curl` into `python3` gets flagged as download-exec by the local security scanner and burns an approval round-trip. Never print key contents.
4. **Report state, not narrative:** what is up, what is degraded (name the component and its exact error), open blockers, spend vs budget if a dashboard exists, then one line asking whether to fix or leave it. The user reads these reports on Slack — lead with the verdict ("control plane up, engineer runner down"), not the investigation.

## Uninstall procedure

**Standing user rule: never remove the agent's own runtime as a side effect.** Before deleting anything, separate app-owned paths from agent-owned paths (`~/.hermes` is Hermes itself — config, memory, skills; deleting it removes the agent). App-embedded identity (an API key stored under the app's dir) is disposable; the agent's own dirs are not.

1. **Inventory and report blast radius BEFORE deleting:** `du -sh` each dir, process list with parent terminal, references in shell rc files / systemd / crontab / Hermes config, npx cache path (derive from the running process's binary path, don't guess the hash). Present: what will be removed, what data dies with it (a DB wipe is irreversible), what is independent and survives. Get explicit go-ahead — the user wants the consequences before the rm, and may not realize what is bundled with the app.
2. **Stop processes.** Pitfall: `pkill -f "<pattern>"` self-matches the invoking shell whenever the pattern string appears in the command line (the shell's own cmdline contains your script text) — the kill call terminates itself (exit -15). Use explicit PIDs from the inventory, or a bracketed pattern like `pkill -f "[p]attern"`. If the kill call dies with signal 15, re-verify process state in a fresh call instead of assuming the kill failed.
3. **Delete:** app data dir, npx/npm cache entry, and any app-specific skills the agent holds for it (they are inert after removal and mislead future sessions). Leave unrelated tooling alone.
4. **Verify the negative, from a fresh call:** no matching processes, port free (`ss -tlnp`), dirs gone, disk reclaimed (`df -h`). Report the reclaimed size.
5. **Clear stale references:** remove the app's entry from memory and the skills library the same session, so no later session acts on the removed system or offers to "check on it".
