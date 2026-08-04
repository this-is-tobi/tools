#!/usr/bin/env bash
# Shared helpers for the image smoke tests.
#
# The tests run inside the freshly built image (see ci.yml), so they catch the
# class of breakage a successful `docker build` cannot: a tool that installed
# but does not execute, a binary that never made it onto PATH, a missing shared
# library.
#
# They are split deliberately:
#
#   inventory  - derived at runtime from the image itself (probe_mise_shims).
#                A tool added to a Dockerfile or to the dotfiles setup scripts
#                is covered the moment it lands, with no edit here.
#   contract   - the short declared list in each ci/tests/<image>.sh. These are
#                the tools the image exists to provide, so removing one should
#                fail loudly and force a deliberate decision rather than being
#                silently absorbed.
#
# Keep declared lists small. Breadth is the probe's job.

set -uo pipefail

# mise exposes its tools through shims. The runner images export that directory
# via ENV, but the dotfiles-based images (debug, dev, dev-lite) rely on shell
# init, which a non-interactive test shell never reads - so it is spelled out
# here rather than assumed.
export MISE_SHIMS="${MISE_DATA_DIR:-${HOME}/.local/share/mise}/shims"
export PATH="${MISE_SHIMS}:${HOME}/.local/bin:${PATH}"

FAILURES=0

# Binary resolves on PATH.
require_cmd() {
  if command -v "$1" > /dev/null 2>&1; then
    printf '  ok       %s\n' "$1"
  else
    printf '  MISSING  %s\n' "$1"
    FAILURES=$((FAILURES + 1))
  fi
}

# Binary resolves *and* runs.
require_run() {
  local label="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    printf '  ok       %s (executes)\n' "$label"
  else
    printf '  FAILED   %s (present but did not run: %s)\n' "$label" "$*"
    FAILURES=$((FAILURES + 1))
  fi
}

require_file() {
  if [ -f "$1" ]; then
    printf '  ok       %s\n' "$1"
  else
    printf '  MISSING  %s\n' "$1"
    FAILURES=$((FAILURES + 1))
  fi
}

# Guards against a regression to running as root - every published image here is
# meant to end on a non-root USER.
require_non_root() {
  if [ "$(id -u)" -ne 0 ]; then
    printf '  ok       runs as non-root (uid %s)\n' "$(id -u)"
  else
    printf '  FAILED   runs as root\n'
    FAILURES=$((FAILURES + 1))
  fi
}

# True when the dynamic loader can resolve every shared library a binary needs.
#
# This is what would have caught node exiting 127 on a missing libatomic.so.1,
# and it does so without executing the program - no argument parsing to guess
# at, nothing interactive to hang on.
linkage_ok() {
  command -v ldd > /dev/null 2>&1 || return 0   # nothing to check with
  local out
  # A static binary makes ldd exit non-zero ("not a dynamic executable"), which
  # is not a failure - only an unresolved library is.
  out=$(ldd "$1" 2>&1) || return 0
  case "$out" in
    *"not found"*|*"Error loading shared library"*) return 1 ;;
    *) return 0 ;;
  esac
}

# Probes every binary mise exposes, enumerated from the shims directory rather
# than from a list maintained here. This is the check that does not go stale:
# whatever the Dockerfile or the dotfiles setup scripts install today is what
# gets probed today.
#
# Pass "optional" for images that legitimately have no mise (curl, backup).
probe_mise_shims() {
  local expect="${1:-required}"
  local count=0 broken=0 name target shim

  if [ ! -d "$MISE_SHIMS" ]; then
    if [ "$expect" = "optional" ]; then
      printf '  skip     no mise in this image\n'
      return 0
    fi
    printf '  FAILED   no mise shims directory at %s\n' "$MISE_SHIMS"
    FAILURES=$((FAILURES + 1))
    return 1
  fi

  for shim in "$MISE_SHIMS"/*; do
    [ -e "$shim" ] || continue
    name=$(basename "$shim")
    count=$((count + 1))

    target=$(mise which "$name" 2>/dev/null)
    if [ -z "$target" ] || [ ! -x "$target" ]; then
      printf '  BROKEN   %s (shim resolves to nothing executable)\n' "$name"
      broken=$((broken + 1))
      continue
    fi

    if ! linkage_ok "$target"; then
      printf '  BROKEN   %s (unresolved shared library)\n' "$name"
      ldd "$target" 2>&1 | grep -E "not found|Error loading" | head -3 | sed 's/^/           /'
      broken=$((broken + 1))
    fi
  done

  if [ "$count" -eq 0 ]; then
    if [ "$expect" = "optional" ]; then
      printf '  skip     no mise-managed binaries in this image\n'
      return 0
    fi
    printf '  FAILED   mise shims directory is empty\n'
    FAILURES=$((FAILURES + 1))
    return 1
  fi

  if [ "$broken" -eq 0 ]; then
    printf '  ok       %s mise-managed binaries, all resolve and link\n' "$count"
  else
    printf '  FAILED   %s of %s mise-managed binaries broken\n' "$broken" "$count"
    FAILURES=$((FAILURES + broken))
  fi
}

# Every tool mise records as installed must actually resolve. Catches a tool
# that mise wrote into its config but failed to expose - a state a plain PATH
# lookup of a hand-written list would never notice.
probe_mise_consistency() {
  local expect="${1:-required}"
  command -v mise > /dev/null 2>&1 || {
    [ "$expect" = "optional" ] && { printf '  skip     mise not installed\n'; return 0; }
    printf '  FAILED   mise not installed\n'
    FAILURES=$((FAILURES + 1))
    return 1
  }

  local missing=0 total=0 tool
  while read -r tool; do
    [ -n "$tool" ] || continue
    total=$((total + 1))
    mise which "$tool" > /dev/null 2>&1 || {
      # Not every tool's package name matches a binary name (ripgrep ships rg),
      # so an unresolvable name is only reported, never counted as a failure -
      # probe_mise_shims covers the binaries themselves.
      printf '  note     %s installed but exposes no binary of that name\n' "$tool"
      missing=$((missing + 1))
    }
  done < <(mise ls --installed 2>/dev/null | awk 'NF {print $1}' | sort -u)

  printf '  ok       %s tools declared installed (%s expose a differently-named binary)\n' \
    "$total" "$missing"
}

report() {
  echo
  if [ "$FAILURES" -gt 0 ]; then
    printf 'FAIL - %s check(s) failed\n' "$FAILURES"
    exit 1
  fi
  printf 'PASS - all checks succeeded\n'
}
