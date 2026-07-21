#!/usr/bin/env bash
# bootstrap-tools.sh — reproducible toolchain bootstrap for ai-usage-meter (SPEC 01).
#
# Pins: uv 0.11.29, Python 3.14.6, pip 26.1.2, PlatformIO 6.1.19,
# esptool 4.11.0, Gitleaks 8.30.1. macOS arm64 only.
# Artifact hashes are read from toolchain/bootstrap-checksums.txt;
# any hash mismatch aborts the bootstrap.
set -euo pipefail
umask 077

UV_VERSION="0.11.29"
PYTHON_VERSION="3.14.6"
PIP_VERSION="26.1.2"
PLATFORMIO_VERSION="6.1.19"
ESPTOOL_VERSION="4.11.0"
GITLEAKS_VERSION="8.30.1"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT/.tools"
VENV_DIR="$ROOT/.venv-tools"
LOCK_FILE="$ROOT/requirements-tools.lock"
CHECKSUMS_FILE="$ROOT/toolchain/bootstrap-checksums.txt"

fail() { echo "bootstrap: ERROR: $*" >&2; exit 1; }

# 1. Reject any platform other than macOS arm64.
[ "$(uname -s)" = "Darwin" ] || fail "unsupported OS: $(uname -s) (baseline certifies macOS only)"
[ "$(uname -m)" = "arm64" ] || fail "unsupported arch: $(uname -m) (baseline certifies arm64 only)"

[ -f "$CHECKSUMS_FILE" ] || fail "missing $CHECKSUMS_FILE"
[ -f "$LOCK_FILE" ] || fail "missing $LOCK_FILE"

expected_sha() { awk -v f="$1" '$2 == f { print $1 }' "$CHECKSUMS_FILE"; }

verify_download() { # <file> <artifact-name>
  local sha; sha="$(expected_sha "$2")"
  [ -n "$sha" ] || fail "no pinned SHA-256 for $2 in $CHECKSUMS_FILE"
  echo "$sha  $1" | shasum -a 256 -c - >/dev/null || fail "SHA-256 mismatch for $2 — rejected"
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# 2. Obtain or validate uv 0.11.29 (artifact hash pinned; any other version rejected).
UV_DIR="$TOOLS_DIR/uv-$UV_VERSION"
UV_BIN="$UV_DIR/uv"
if [ ! -x "$UV_BIN" ]; then
  artifact="uv-aarch64-apple-darwin.tar.gz"
  url="$(awk -v f="$artifact" '$2 == f { print $3 }' "$CHECKSUMS_FILE")"
  echo "bootstrap: downloading uv $UV_VERSION"
  curl -fsSL "$url" -o "$TMP_DIR/$artifact"
  verify_download "$TMP_DIR/$artifact" "$artifact"
  mkdir -p "$UV_DIR"
  tar -xzf "$TMP_DIR/$artifact" -C "$UV_DIR" --strip-components=1
fi
[ "$("$UV_BIN" --version | awk '{print $2}')" = "$UV_VERSION" ] \
  || fail "uv at $UV_BIN is not $UV_VERSION"

# 3. Install Python 3.14.6 with the pinned uv.
"$UV_BIN" python install "$PYTHON_VERSION"

# 4. Create .venv-tools with seed (pip available).
"$UV_BIN" venv --python "$PYTHON_VERSION" --seed --clear "$VENV_DIR"

# 5. Install the lock with hash validation and no transitive re-resolution.
"$VENV_DIR/bin/python" -m pip install --require-hashes --no-deps -r "$LOCK_FILE"

# 6. Validate pip 26.1.2 BEFORE any PlatformIO command runs.
PIP_REPORTED="$("$VENV_DIR/bin/python" -m pip --version | awk '{print $2}')"
[ "$PIP_REPORTED" = "$PIP_VERSION" ] || fail "pip is $PIP_REPORTED, expected $PIP_VERSION"

# 7. Only now may PlatformIO execute.
[ "$("$VENV_DIR/bin/pio" --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')" = "$PLATFORMIO_VERSION" ] \
  || fail "PlatformIO is not $PLATFORMIO_VERSION"
[ "$("$VENV_DIR/bin/esptool.py" version 2>/dev/null | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -1 | tr -d v)" = "$ESPTOOL_VERSION" ] \
  || fail "esptool is not $ESPTOOL_VERSION"

# 8. Download Gitleaks 8.30.1, validate SHA-256, keep in .tools/.
GL_DIR="$TOOLS_DIR/gitleaks-$GITLEAKS_VERSION"
GL_BIN="$GL_DIR/gitleaks"
if [ ! -x "$GL_BIN" ]; then
  artifact="gitleaks_${GITLEAKS_VERSION}_darwin_arm64.tar.gz"
  url="$(awk -v f="$artifact" '$2 == f { print $3 }' "$CHECKSUMS_FILE")"
  echo "bootstrap: downloading gitleaks $GITLEAKS_VERSION"
  curl -fsSL "$url" -o "$TMP_DIR/$artifact"
  verify_download "$TMP_DIR/$artifact" "$artifact"
  mkdir -p "$GL_DIR"
  tar -xzf "$TMP_DIR/$artifact" -C "$GL_DIR"
fi
[ "$("$GL_BIN" version)" = "$GITLEAKS_VERSION" ] || fail "gitleaks is not $GITLEAKS_VERSION"

# Final validation: every executable via its controlled absolute path.
echo "bootstrap: validating executables"
"$VENV_DIR/bin/python" --version
"$VENV_DIR/bin/python" -m pip --version
"$VENV_DIR/bin/pio" --version
"$VENV_DIR/bin/esptool.py" version
"$GL_BIN" version
echo "bootstrap: OK"
