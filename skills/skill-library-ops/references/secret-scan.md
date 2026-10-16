# Secret-scan patterns for publishing skills/config to git

Run from the staged copy root. Two passes: high-confidence key material, then
credential-bearing URLs and random-looking strings.

## Pass 1 — key formats (any hit = block the push)

```sh
grep -rniE '(ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_|sk-[A-Za-z0-9]{20,}|sk-ant-|xox[baprs]-|AKIA[0-9A-Z]{16}|BEGIN (RSA|OPENSSH|EC) PRIVATE|Bearer [A-Za-z0-9_\-\.]{20,}|api[_-]?key["'"' ]*[:=]["'"' ]*[A-Za-z0-9_\-]{16,}|password["'"' ]*[:=]|secret["'"' ]*[:=][ ]*["'"']?[A-Za-z0-9]{12,})'
```

## Pass 2 — embedded credentials in URLs and entropy

```sh
grep -rnoE 'https?://[^ "'"']+:[^ @/]+@[^ "'"' ]+' .   # user:pass@ URLs
grep -rnoE '[A-Fa-f0-9]{32,}|[A-Za-z0-9+/]{40,}={0,2}' --include='*.md' --include='*.sh' --include='*.py' --include='*.service' .
```
Filter pass-2 hits that are prose (`sha256`, `example`, repeated filler) before judging.

## Judging hits

- `<token>`, `<vault>`, `__var_name__` placeholders → SAFE (documentation of the mechanism).
- Prose naming WHERE secrets live (`/etc/restic-backup/offsite.env`, "rotate keys in dashboard") → SAFE; that is operational knowledge, not the secret.
- Literal key material, passwords, or real cred-bearing URLs → BLOCK. Tell the user what was found and redact before pushing.
- Hostnames, tailnet names, instance IDs, org names → allowed in private repos once the user has confirmed private visibility.
