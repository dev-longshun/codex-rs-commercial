# Codex Client One-Click Setup

This folder provides end-user setup scripts for Codex CLI with your proxy endpoint.

## What these scripts do

- Check/install Node.js and npm
- Install or update `@openai/codex` to latest
- Ask user to paste config text once (smart parsing), for example:
  - `API Base URL: https://your-domain`
  - `API Key: sk-xxxxxx`
- Write:
  - `OPENAI_BASE_URL`
  - `OPENAI_API_KEY`
- Users can run `codex` directly after setup

## Scripts

- macOS (double-click): `setup-codex-macos.command`
- Linux: `setup-codex-linux.sh`
- Windows (PowerShell): `setup-codex-windows.ps1`

## Notes

- Supports parsing these formats:
  - `API Base URL: ...` / `Base URL: ...` / `URL: ...`
  - `API Key: ...` / `Key: ...`
  - `OPENAI_BASE_URL=...` / `OPENAI_API_KEY=...`
- Base URL entered as host will be normalized to include `/v1`.
- For Windows PowerShell 5.1 compatibility, keep `setup-codex-windows.ps1` as UTF-8 with BOM if you edit and save it manually.
- Keep API keys private and rotate periodically.
