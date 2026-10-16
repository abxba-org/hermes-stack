---
name: vps-system-ops
description: "VPS system-level admin: disk space, swap, services."
version: 1.0.0
author: Hermes Agent
metadata:
  hermes:
    tags: [vps, sysadmin, swap, display, systemd, disk]
    related_skills: [local-service-ops]
---

# VPS System Ops

## When to Use

- The user asks to install, change, or remove system-level components on their VPS: display manager / desktop environment, swap, kernel/sysctl settings, systemd services, packages.
- The VPS is slow and the cause may be system-level (memory pressure, swap, resident services).
- 'No space available' errors or a near-full filesystem on the VPS (disk-space triage and reclaim).
- Any task where you are unsure whether the target box is the VPS or a separate machine.

Scope: system-level changes on the box Hermes itself runs on (the user's OVH VPS) — display stack, swap, memory, packages, systemd services. Health-checks and teardown of self-hosted *apps* belong to `local-service-ops`.

## Environment facts

- **Hermes runs ON the VPS.** The hostname of this machine is the VPS's own (`vps-1558ffa7`, also reachable as `vps-ovh.tail95f2ee.ts.net` on the tailnet). When a task targets the VPS, run `hostname` first and work locally via `terminal` + `sudo` — do not burn calls on SSH attempts to the VPS names; they fail with publickey denial because no authorized key exists.
- 2 vCPU, 3.7 GB RAM, 38 GB disk. Baseline RAM consumers (Hermes runtimes, kilo, Alloy, skillspector) leave thin headroom — check `free -h` before adding any resident service, and never run without swap.
- **The graphical display is for agents only, never for the user.** Keep the display stack headless: no auto-started desktop manager or greeter; prefer on-demand virtual displays (Xvfb) for agent tooling. This is the user's standing decision — do not re-offer a human-facing desktop, VNC-for-humans, or a graphical login.

## Change procedure

1. **Plan-first gate:** present findings + options and get an explicit go/no-go before any install/enable/disable on this box. When the initial ask is ambiguous or garbled, verify live state first (processes, packages, ports) and restate the real situation before proposing options — the fix is often not the one the user asked for.
2. **Order of operations:** when a change removes something currently running, stand up and verify its replacement first, then stop the old thing — never leave the user or agent tooling locked out mid-change.
3. **Batch + verify:** run a system change as one `set -e` script ending in a `---VERIFY---` block that checks the actual state (`swapon --show`, `free -h`, `ss -tlnp`, process list). Report verified state, never intentions.

## Security-approval gate

- `sudo tee`/append to protected paths (`/etc/fstab`, `/etc/sysctl.d/*`, unit files) and service enable/disable commands trigger a runtime approval prompt the user must answer **in the approval prompt UI, not in Slack chat**. A chat reply does not satisfy the gate; the prompt times out (~5 min) and the command is blocked with 'silence is not consent'.
- When issuing a gated command, warn in the same message that consent must be given via the approval prompt itself. If it times out, do not re-issue or rephrase it — wait for the user's explicit go.

## Disk space reclaim (validated)

Triage order — drill from the top down, never start inside /home:

1. `df -h /` to confirm the full filesystem and free headroom.
2. `sudo du -xh / --max-depth=1 | sort -rh | head` to rank top-level consumers, then `--max-depth=2` on the big ones (typically /home, /root, /var, /usr).
3. Classify each consumer before touching it: **regenerable cache** (safe to delete on the user's plain 'remove space' ask), **live data** (ask first, always).
4. Delete caches in one batch, end with `df -h /` and report the before/after free-space delta.

Safe cache targets (all auto-regenerate): `~/.cache/go-build`, `uv cache clean`, `pip cache purge`, `npm cache clean --force`, `sudo apt-get clean`, `/var/lib/snapd/cache/*`, `~/.cache/huggingface` (model re-downloads), old `/root/*.backup*` copies of migrated data, `sudo journalctl --vacuum-size=50M`.

Live data that must never be bulk-deleted on this box: the user's repos, and **each Hermes install's `.hermes` directory** (`tools/` is the Python/Node runtime a running session depends on). This VPS has TWO live Hermes users — `/home/ubuntu` and `/home/hermes` (separate profiles, its own running process). Before calling anything under a foreign home dir junk, check `ps aux | grep -i herm[e]` — a dir owned by a user with live processes is runtime, not garbage.

Pitfalls:
- **No sudo du on a foreign home dir without bash -c.** `sudo du -sh /home/otheruser/*` expands the glob as the unprivileged user and matches nothing (silently empty output with `2>/dev/null`) — wrap it as `sudo bash -c 'du -sh /home/otheruser/* ...'`. Expect tirith to flag `sudo bash -c` as an interactive-root-shell HIGH and require approval; that is the price of getting real output.
- **Hidden dirs dominate home.** A plain `du -sh /home/user/*` misses `.[!.]*` dot-dirs — cache bloat (go-build, .npm, .nvm, .hermes, .local) lives there; glob both forms.
- **Present the classification to the user, not just a delete plan.** Say what each pile is and why it accumulated (caches grow unbounded; package managers keep every tarball; old migration backups are never auto-cleaned) — the user asks for the reasons and approves non-cache deletes item by item.

## Memory/swap recipe (validated)

First fix for a slow low-RAM box with no swap:

```sh
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swap.conf >/dev/null
sudo sysctl -w vm.swappiness=10
```

Verify: `swapon --show` shows the file at priority -1 and `free -h` shows Swap total. Size to ~RAM (4G on a 3.7G box); check `df -h /` headroom first.
