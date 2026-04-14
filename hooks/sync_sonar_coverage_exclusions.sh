#!/usr/bin/env bash
# Expects [tool.coverage.run] omit = ["one-line", "toml", "array"] in pyproject.toml.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
PYPROJECT="${REPO_ROOT}/pyproject.toml"
SONAR_PROPS="${REPO_ROOT}/sonar-project.properties"

SYNC_SONAR_TMP=
cleanup_sync_sonar_tmp() {
  [[ -n "${SYNC_SONAR_TMP}" ]] && rm -f -- "${SYNC_SONAR_TMP}"
}

map_sonar_pattern() {
  local p="$1"
  if [[ "$p" == '*__init__*' ]]; then
    printf '%s' '**/__init__.py'
  elif [[ "$p" == *'/*' ]]; then
    printf '%s' "${p%/*}/**"
  else
    printf '%s' "$p"
  fi
}

coverage_omit_line() {
  awk '
    /^\[tool\.coverage\.run\]/ { inrun = 1; next }
    /^\[/ { if (inrun) inrun = 0; next }
    inrun && /^[[:space:]]*omit[[:space:]]*=/ { print; exit }
  ' "$PYPROJECT"
}

patterns_csv_from_pyproject() {
  local line inner
  line="$(coverage_omit_line || true)"
  [[ -n "$line" ]] || { echo ""; return; }
  if [[ "$line" =~ ^[[:space:]]*omit[[:space:]]*=[[:space:]]*\[(.*)\][[:space:]]*$ ]]; then
    inner="${BASH_REMATCH[1]}"
  else
    echo ""
    return
  fi
  local first=1 csv="" tok
  while IFS= read -r tok; do
    tok="${tok#\"}"
    tok="${tok%\"}"
    [[ -n "$tok" ]] || continue
    local mapped
    mapped="$(map_sonar_pattern "$tok")"
    if [[ "$first" -eq 1 ]]; then
      csv="$mapped"
      first=0
    else
      csv="${csv},${mapped}"
    fi
  done < <(grep -oE '"[^"]*"' <<<"$inner" || true)
  printf '%s' "$csv"
}

sonar_coverage_exclusions_line() {
  local csv
  csv="$(patterns_csv_from_pyproject)"
  if [[ -z "$csv" ]]; then
    printf '%s\n' "sonar.coverage.exclusions="
  else
    printf '%s\n' "sonar.coverage.exclusions=${csv}"
  fi
}

apply_sonar_block() {
  local nl="$1"
  awk -v NL="$nl" '
    BEGIN { inserted = 0 }
    /^sonar\.coverage\.exclusions/ { skip = 1; next }
    skip {
      if (/^  / || /^[[:space:]]*$/) next
      skip = 0
    }
    /^sonar\.tests=/ {
      if (!inserted) { print NL; inserted = 1 }
    }
    { print }
    END {
      if (!inserted) print NL
    }
  ' "$SONAR_PROPS"
}

main() {
  local new_block
  new_block="$(sonar_coverage_exclusions_line)"
  SYNC_SONAR_TMP="$(mktemp)"
  trap cleanup_sync_sonar_tmp EXIT
  apply_sonar_block "$new_block" >"${SYNC_SONAR_TMP}"
  if cmp -s "$SONAR_PROPS" "${SYNC_SONAR_TMP}"; then
    return 0
  fi
  cp "${SYNC_SONAR_TMP}" "$SONAR_PROPS"
  if [[ -z "${SYNC_SONAR_NO_GIT_ADD:-}" ]] && [[ -d "${REPO_ROOT}/.git" ]]; then
    git -C "$REPO_ROOT" add -- sonar-project.properties
  fi
  echo "Updated and staged sonar-project.properties from pyproject.toml coverage omit."
  return 0
}

main "$@"
