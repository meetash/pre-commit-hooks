#!/usr/bin/env bash
# Syncs sonar.coverage.exclusions from [tool.coverage.run] omit in pyproject.toml
# (omit list read via tomllib; Sonar glob mapping and sonar-project.properties merge stay in bash).
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
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

patterns_csv_from_pyproject() {
  local raw csv="" first=1 tok mapped
  local -a items
  raw="$(
    cd "$REPO_ROOT" && python3 -c "import tomllib;d=tomllib.load(open('pyproject.toml','rb'));r=(((d.get('tool')or{}).get('coverage')or{}).get('run'))or{};o=r.get('omit');o=[]if o is None else(o if isinstance(o,list)else[o]);print(','.join(o))"
  )"
  raw="${raw%$'\n'}"
  [[ -n "$raw" ]] || return 0
  IFS=',' read -ra items <<<"$raw" || true
  for tok in "${items[@]}"; do
    [[ -n "$tok" ]] || continue
    mapped="$(map_sonar_pattern "$tok")"
    if [[ "$first" -eq 1 ]]; then
      csv="$mapped"
      first=0
    else
      csv="${csv},${mapped}"
    fi
  done
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

