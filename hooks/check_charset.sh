#!/usr/bin/env bash
# Fail if staged text files contain Unicode that often breaks tooling or review.
set -euo pipefail

PATTERN='[\x{00A0}\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2066}-\x{2069}\x{FEFF}\x{2018}-\x{201F}]'

if [ "$#" -eq 0 ]; then
  exit 0
fi

found=0

for file in "$@"; do
  if [ ! -f "$file" ]; then
    continue
  fi

  if grep -PHIn "$PATTERN" -- "$file" >/dev/null 2>&1; then
    if [ "$found" -eq 0 ]; then
      echo >&2 ""
      echo >&2 "check-charset: Forbidden Unicode characters found (smart quotes, NBSP, zero-width or bidi marks, etc.)."
      echo >&2 "Replace them with ASCII equivalents in the following locations:"
      echo >&2 ""
    fi
    grep -PHIn "$PATTERN" -- "$file" >&2
    found=1
  fi
done

exit "$found"
