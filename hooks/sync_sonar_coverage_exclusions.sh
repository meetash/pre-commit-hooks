#!/usr/bin/env bash
# Syncs sonar.coverage.exclusions from [tool.coverage.run] omit in pyproject.toml.
# Supports both single-line and multi-line omit = [ ... ] arrays.
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

# Prints one omit glob per line (unquoted path), or nothing if omit is missing / empty.
omit_patterns_from_pyproject() {
  awk '
    BEGIN { inrun = 0; inomit = 0; buf = "" }

    /^\[/ {
      if ($0 == "[tool.coverage.run]") {
        inrun = 1
        inomit = 0
        buf = ""
        next
      }
      if (inrun) {
        inrun = 0
        inomit = 0
        buf = ""
      }
      next
    }

    !inrun { next }

    /^[[:space:]]*omit[[:space:]]*=/ {
      inomit = 1
      sub(/^[[:space:]]*omit[[:space:]]*=[[:space:]]*/, "")
      buf = $0
      if (buf ~ /\]/) {
        while (match(buf, /"[^"]*"/)) {
          print substr(buf, RSTART + 1, RLENGTH - 2)
          buf = substr(buf, RSTART + RLENGTH)
        }
        inomit = 0
        buf = ""
      }
      next
    }

    inomit {
      buf = buf "\n" $0
      if (buf ~ /\]/) {
        while (match(buf, /"[^"]*"/)) {
          print substr(buf, RSTART + 1, RLENGTH - 2)
          buf = substr(buf, RSTART + RLENGTH)
        }
        inomit = 0
        buf = ""
      }
      next
    }
  ' "$PYPROJECT"
}

patterns_csv_from_pyproject() {
  local first=1 csv="" tok
  while IFS= read -r tok || [[ -n "$tok" ]]; do
    [[ -n "$tok" ]] || continue
    local mapped
    mapped="$(map_sonar_pattern "$tok")"
    if [[ "$first" -eq 1 ]]; then
      csv="$mapped"
      first=0
    else
      csv="${csv},${mapped}"
    fi
  done < <(omit_patterns_from_pyproject)
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
