#!/usr/bin/env bash
# Scan staged changes only. New secrets must be fixed or explicitly allowed.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
GITLEAKS=""

if [ -x "$REPO_ROOT/.gitleaks-bin/gitleaks" ]; then
  GITLEAKS="$REPO_ROOT/.gitleaks-bin/gitleaks"
elif command -v gitleaks >/dev/null 2>&1; then
  GITLEAKS="gitleaks"
fi

if [ -z "$GITLEAKS" ]; then
  echo >&2 "gitleaks not found; install it before committing:"
  echo >&2 "  macOS: brew install gitleaks"
  echo >&2 "  Ubuntu/Debian: sudo apt install gitleaks"
  echo >&2 "  Other Linux: use your distro package manager if available, or download from https://github.com/gitleaks/gitleaks/releases and place it on PATH."
  exit 1
fi

"$GITLEAKS" git --pre-commit --staged . --redact --verbose
