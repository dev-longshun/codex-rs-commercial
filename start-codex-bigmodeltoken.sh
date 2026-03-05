#!/bin/bash
set -euo pipefail

PROJECT_DIR="/Users/longshun/Desktop/Program/00_use/CLIProxyAPI"
BASE_URL="${OPENAI_BASE_URL:-https://bigmodeltoken.zeabur.app}"
PROJECT_CODEX_HOME="${PROJECT_DIR}/.codex-bigmodeltoken"
API_KEY="${OPENAI_API_KEY:-}"

if [[ -z "$API_KEY" ]]; then
  read -r -s -p "Enter OPENAI_API_KEY: " API_KEY
  echo
fi

if [[ -z "$API_KEY" ]]; then
  echo "OPENAI_API_KEY is required." >&2
  exit 1
fi

BASE_URL="${BASE_URL%/}"
if [[ "$BASE_URL" != */v1 ]]; then
  BASE_URL="${BASE_URL}/v1"
fi

cd "$PROJECT_DIR"
mkdir -p "$PROJECT_CODEX_HOME"

export CODEX_HOME="$PROJECT_CODEX_HOME"
export OPENAI_BASE_URL="$BASE_URL"
export OPENAI_API_KEY="$API_KEY"
export CODEX_API_KEY="$OPENAI_API_KEY"

# Ensure this project-scoped Codex profile always uses the intended API key.
printf '%s' "$OPENAI_API_KEY" | codex login --with-api-key >/dev/null 2>&1 || true

exec codex --dangerously-bypass-approvals-and-sandbox "$@"
