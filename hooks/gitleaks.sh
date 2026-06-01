#!/usr/bin/env bash
# Scan staged changes only. New secrets must be fixed or explicitly allowed.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITLEAKS="$REPO_ROOT/.gitleaks-bin/gitleaks"

if [ ! -x "$GITLEAKS" ] || ! "$GITLEAKS" git --help >/dev/null 2>&1; then
  "$HOOK_DIR/../scripts/install-gitleaks.sh"
fi

if [ ! -x "$GITLEAKS" ]; then
  echo >&2 "gitleaks not found at ${GITLEAKS} after install."
  echo >&2 "Run: ${HOOK_DIR}/../scripts/install-gitleaks.sh"
  exit 1
fi

cd "$REPO_ROOT"
"$GITLEAKS" git --pre-commit --staged . --redact --verbose
