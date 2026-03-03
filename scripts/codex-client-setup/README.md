# Codex Client One-Click Setup

This folder provides end-user setup scripts for Codex CLI with your proxy endpoint.

## What these scripts do

- Check/install Node.js and npm
- Install or update `@openai/codex` to latest
- Ask user for:
  - Base URL
  - API key
- Write:
  - `OPENAI_BASE_URL`
  - `OPENAI_API_KEY`
- Users can run `codex` directly after setup

## Scripts

- macOS (double-click): `setup-codex-macos.command`
- Linux: `setup-codex-linux.sh`
- Windows (PowerShell): `setup-codex-windows.ps1`

## Notes

- Base URL entered as host will be normalized to include `/v1`.
- Keep API keys private and rotate periodically.

