#!/usr/bin/env bash
set -euo pipefail

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "[secret-scan] gitleaks not found."
  echo "[secret-scan] Install: https://github.com/gitleaks/gitleaks"
  exit 1
fi

echo "[secret-scan] scanning working tree..."
gitleaks detect \
  --source . \
  --no-git \
  --redact \
  --exit-code 1

echo "[secret-scan] no secrets detected."
