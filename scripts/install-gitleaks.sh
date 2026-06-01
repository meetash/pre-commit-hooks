#!/usr/bin/env bash
# Install or upgrade the latest gitleaks release into the consuming repo's .gitleaks-bin/.
# Override the version with: GITLEAKS_VERSION=8.30.1 ./scripts/install-gitleaks.sh
# Verifies the downloaded tarball against gitleaks_<version>_checksums.txt from the same release.

set -euo pipefail

sha256_hex() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  else
    shasum -a 256 "$1" | awk '{ print $1 }'
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
INSTALL_DIR="$REPO_ROOT/.gitleaks-bin"
BINARY="$INSTALL_DIR/gitleaks"

if [ -n "${CI:-}" ]; then
  exit 0
fi

if [ -z "${GITLEAKS_VERSION:-}" ]; then
  json="$(
    curl -sS --connect-timeout 10 \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/gitleaks/gitleaks/releases/latest" 2>/dev/null || true
  )"
  tag_name="$(printf '%s' "$json" | sed -nE 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v?([^"]+)".*/\1/p' | head -n1)"
  if [ -z "$tag_name" ]; then
    echo "Error: could not resolve latest gitleaks from GitHub." >&2
    echo "Set GITLEAKS_VERSION manually or check your network connection." >&2
    exit 1
  fi
  GITLEAKS_VERSION="$tag_name"
fi
GITLEAKS_VERSION="${GITLEAKS_VERSION#v}"

if [ -x "$BINARY" ]; then
  installed="$("$BINARY" version 2>/dev/null | sed -nE 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | head -n1)"
  if [ "$installed" = "$GITLEAKS_VERSION" ] && "$BINARY" git --help >/dev/null 2>&1; then
    echo "gitleaks ${installed} already installed at ${BINARY}"
    exit 0
  fi
fi

case "$(uname -s)" in
  Darwin*) OS=darwin ;;
  Linux*) OS=linux ;;
  *)
    echo "Error: unsupported OS for gitleaks auto-install: $(uname -s)" >&2
    exit 1
    ;;
esac

case "$(uname -m)" in
  x86_64 | amd64)
    if [ "$OS" = darwin ]; then
      ARCH_SUFFIX=darwin_x64
    else
      ARCH_SUFFIX=linux_x64
    fi
    ;;
  arm64 | aarch64)
    if [ "$OS" = darwin ]; then
      ARCH_SUFFIX=darwin_arm64
    else
      ARCH_SUFFIX=linux_arm64
    fi
    ;;
  *)
    echo "Error: unsupported arch for gitleaks auto-install: $(uname -m)" >&2
    exit 1
    ;;
esac

ASSET="gitleaks_${GITLEAKS_VERSION}_${ARCH_SUFFIX}.tar.gz"
URL="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/${ASSET}"
CHECKSUMS_URL="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_checksums.txt"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ARCHIVE="$TMP/$ASSET"
CHECKSUMS_FILE="$TMP/gitleaks_${GITLEAKS_VERSION}_checksums.txt"

echo "Installing gitleaks ${GITLEAKS_VERSION} (${ARCH_SUFFIX}) to ${INSTALL_DIR}/ ..."
if ! curl -sSfL -o "$ARCHIVE" "$URL"; then
  echo "Error: could not download gitleaks ${GITLEAKS_VERSION}." >&2
  exit 1
fi

if ! curl -sSfL -o "$CHECKSUMS_FILE" "$CHECKSUMS_URL"; then
  echo "Error: could not download gitleaks checksums; refusing to install without verification." >&2
  exit 1
fi

expected="$(
  awk -v f="$ASSET" 'NF >= 2 && ($2 == f || $2 == "./" f) { print $1; exit }' "$CHECKSUMS_FILE"
)"
if [ -z "$expected" ]; then
  echo "Error: no SHA-256 entry for $ASSET in release checksums." >&2
  exit 1
fi

actual="$(sha256_hex "$ARCHIVE")"
expected_lc="$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')"
actual_lc="$(printf '%s' "$actual" | tr '[:upper:]' '[:lower:]')"
if [ "$expected_lc" != "$actual_lc" ]; then
  echo "Error: gitleaks archive SHA-256 does not match GitHub checksums." >&2
  exit 1
fi

if ! tar -xzf "$ARCHIVE" -C "$TMP"; then
  echo "Error: could not extract gitleaks archive." >&2
  exit 1
fi

if [ ! -f "$TMP/gitleaks" ]; then
  echo "Error: gitleaks archive did not contain expected binary." >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"
mv "$TMP/gitleaks" "$BINARY"
chmod +x "$BINARY"

echo "Installed gitleaks at ${BINARY}"
