---
name: grafana-cloud-observability
description: Use when wiring Grafana Cloud logs/metrics/traces (Alloy).
---

# Grafana Cloud observability via Grafana Alloy

Reference implementation lives on `vps-1558ffa7` (config: `/etc/alloy/config.alloy`, master copy in `~/.hermes/cache/scratch/config.alloy` — scratch may be pruned, recreate if missing).

## Install (Ubuntu)

```bash
sudo apt-get install -y apt-transport-https wget gpg
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update && sudo apt-get install -y alloy auditd
sudo systemctl enable --now auditd
```

## Credentials — collect these from the user

Grafana Cloud shows a DIFFERENT numeric username per service (Loki, Prometheus, Tempo) — do not reuse one. Files under `/etc/alloy/` (mode 640, owner alloy:alloy):
`cloud_token`, `prom_username`, `loki_username`, `tempo_username`, `loki_url` (full push URL incl. `/loki/api/v1/push`), `prom_url` (`/api/prom/push`), `tempo_url` (base incl. `/tempo` — otlphttp appends `/v1/traces`).

User creates: Cloud Portal → Security → Access Policies → scopes `logs:write`, `metrics:write`, `traces:write` → Add token (shown once). Endpoints: Details on each service tile.

## Config pitfalls (Alloy v1.20)

- stdlib is `string.trim_space` (not `strings.`); env vars are `sys.env("X")`.
- journald component is `loki.source.journal` (no 'd'); to expose unit names, `relabel_rules = discovery.relabel.x.rules` — the CAPSULE export `.rules`, NOT `.output` (array). Journal meta labels are `__journal__systemd_unit`, `__journal_syslog_identifier`.
- `alloy validate` passes configs that fail at runtime — don't trust it for component args; watch `journalctl -u alloy`.
- `loki.process` stage.labels uses `values = { label = "source" }`.
- Inject hostname via systemd drop-in (`/etc/systemd/system/alloy.service.d/env.conf` with `[Service]` header + `Environment=HOSTNAME=...`) then `sys.env("HOSTNAME")`.
- auditd writes to `/var/log/audit/audit.log`, NOT journald — must scrape it separately.
- OTLP receiver: bind 4317/4318 (localhost only for this setup); traces/logs/metrics routed to tempo exporter / otelcol.exporter.loki / otelcol.exporter.prometheus respectively.

## Verification (token has WRITE scopes only — Loki read API returns 'invalid scope requested', that's normal)

```bash
systemctl is-active alloy
curl -s localhost:12345/metrics | grep -E '^loki_write_(sent_entries|dropped_entries)_total'
curl -s localhost:12345/metrics | grep '^prometheus_remote_storage_samples_failed_total'
sudo journalctl -u alloy --since '-5 min' | grep -c 'level=error'   # expect 0
```
Expect Loki status_code=204 buckets, dropped_entries 0, samples_failed 0.

## Audit rules for permission tracking

`/etc/audit/rules.d/50-observability.rules`: watches on /etc/passwd, group, shadow, gshadow, sudoers(+d), sshd_config(+d), crontab, cron.d with keys identity/sudoers/sshd_config/cron; load with `sudo augenrules --load`, check `sudo auditctl -l`.

## User queries in Grafana (Explore → Loki)

- SSH logins: `{unit="sshd"}`; sudo usage: `{unit="sudo"}`; failed sudo/su: search `FAILED`; permission denies: `|= "Permission denied"`.
- Metrics: `{instance="<hostname>"}` in Prometheus; dashboards from Grafana's Linux integration or custom.
- Free tier: 10k series, 50GB logs + 50GB traces/month, 14d retention.
