# USER.md — operator guide: moving Hermes + agent-vault to the new VPS

This is YOUR step-by-step checklist (ABXBA). The agent executes the technical steps;
every gate below is yours to call. Read `migrations/MIGRATION.md` once for the
transfer matrix; then follow this in order.

## Step 0 — before anything (5 min, today)

- [ ] Skim `migrations/MIGRATION.md` — know what transfers vs what you re-enter.
- [ ] Confirm the repo is current: `hermes cron list` shows the backup job active,
      last push fresh on GitHub (`gh api repos/abxba-org/hermes-config/commits --jq '.[0].sha'`).
- [ ] Optional but recommended: add SLACK_APP_TOKEN + SLACK_BOT_TOKEN to the vault in
      one more `sudo vault-mgmt on` window (30 min auto-OFF), same as you did for
      RESTIC_PASSWORD / HEVY_API_KEY. Shrinks manual re-entry further.
- [ ] Order/provision the Contabo box; note the IPv4. Target: Ubuntu 24.04, 8GB/100GB.

## Step 1 — snapshot the old box (agent does, ~2 min)

- [ ] Say: "run the migration snapshot". Agent runs `capture-host-snapshot.sh`
      (already wired into the 12h sync) and pushes.

## Step 2 — export the vault (operator GO; ~2 min downtime, seconds really)

- [ ] You say GO. Agent runs `sudo bash migrations/agent-vault/export-vault.sh`
      (stops gateway+vault, bundles, restarts both).
- [ ] Agent copies the bundle to the new box over Tailscale scp:
      `scp /root/vault-migration-bundle.tar.gz vps-contabo:/root/`
      (new box needs Tailscale first — Step 3a).

## Step 3 — build the new box (agent executes, you approve each gate)

Follow `abxba-org/vps-migration-contabo` docs (the phased plan) with this repo's kit:

- [ ] 3a. Base: `scripts/contabo-bootstrap.sh` + Tailscale join (`vps-contabo`) —
      from the Contabo repo.
- [ ] 3b. Vault import: clone this repo on the new box, run
      `sudo bash migrations/agent-vault/import-vault.sh` → verify health + credential
      list + rules (34) intact (checklist in `migrations/agent-vault/VAULT-MIGRATION.md`).
- [ ] 3c. Hermes install + config overlay: guided runner
      `bash migrations/restore-new-vps.sh` (defaults to dedicated `hermes` user).
- [ ] 3d. nftables LAST (per the plan: egress table arms only after install completes).

## Step 4 — secrets you re-enter (only these are left)

- [ ] Slack: SLACK_APP_TOKEN, SLACK_BOT_TOKEN → new `.env` (or skip if you did Step 0
      vault add — then pull from vault instead).
- [ ] `gh auth login` on the new box.
- [ ] `composio link` linear / slack / github (GitHub needs it anyway — expired here).
- [ ] Grafana Alloy remote-write key → new alloy config.
- [ ] Tailscale auth (device join covers it), SSH keys if you use them.

## Step 5 — verification (agent runs, you confirm)

- [ ] Slack message to the bot gets a reply (gateway live through vault proxy).
- [ ] Vault request log shows proxied OpenRouter calls (owner UI).
- [ ] External scan: 14321/14322 NOT reachable from public internet.
- [ ] `hevy_watch.py` cron entry works on the new box (test with --once if available).
- [ ] Backup job: `hermes cron list` on new box — active, next-run advancing.

## Step 6 — switchover (EXPLICIT GO — old box stays live until you say so)

- [ ] You say GO. Agent moves delivery targets / DNS / anything pointing at the old box.
- [ ] Old box keeps running untouched for a soak period you choose (suggest 7 days).

## Step 7 — decommission old box (operator GO, irreversible-ish)

- [ ] Revoke the owner CLI session: `agent-vault auth sessions revoke` (agent can do it).
- [ ] Shred both vault bundles: `shred -u /root/vault-migration-bundle.tar.gz` (both boxes).
- [ ] Rotate: Slack app tokens, tailscale auth keys if shared, vault agent token
      (see Contabo repo `docs/vps2contabo/KEY-ROTATION.md`).
- [ ] Keep the restic password ONLY in the vault + your password manager from here on;
      delete `~/.restic_password` on the old box only after one successful new-box backup.
- [ ] Then (and only then) wipe/deallocate the OVH box.

## If something breaks

- Vault import fails → `journalctl -u agent-vault`; bundle is intact, nothing lost.
- Gateway can't fetch credentials → nftables must allow uid-1003 → 127.0.0.1:14321
  (the most common breakage; see VAULT-MIGRATION.md gotchas).
- Everything recoverable: old box stays live until Step 7 completes.
