# Security Scripts

## Secret Scan

Run before commit/push:

```bash
./scripts/security/scan-secrets.sh
```

Notes:
- Requires `gitleaks` installed locally.
- Scans current working tree (`--no-git`) and redacts matched values in output.
