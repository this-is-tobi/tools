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

# mise exposes its tools through shims. The runner images export those
# directories via ENV, but the dotfiles-based images (debug, dev, dev-lite) rely
# on shell init, which a non-interactive test shell never reads - so they are
# spelled out here rather than assumed. There are two layers: the user's, and the
# system one that gh-runner installs its toolchain into; an image only has the
# layers it uses.
export MISE_SHIMS="${MISE_DATA_DIR:-${HOME}/.local/share/mise}/shims"
export MISE_SYSTEM_SHIMS="${MISE_SYSTEM_DATA_DIR:-/usr/local/share/mise}/shims"
export PATH="${MISE_SHIMS}:${MISE_SYSTEM_SHIMS}:${HOME}/.local/bin:${PATH}"

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

# The welcome message of the dev, dev-lite and debug images (docker/utils/*/motd.sh).
# The silent cases matter as much as the printed one: a banner on a
# non-interactive shell would corrupt `kubectl cp` (tar over exec) and every
# `kubectl exec ... | tool` pipeline. The marker is the line that tells a user how
# to switch the message off, so it is in the output exactly when the message is.
MOTD_MARKER='NO_MOTD=1'

# What a command writes on a pseudo-terminal, the way `docker exec -it` and
# `kubectl exec -it` start it. `script` takes the command as one string. The
# timeout is for a shell that stops to ask something (zsh does, in a home with
# no .zshrc): a hung check would otherwise hold the job until the runner gives up.
motd_on_tty() {
  timeout 60 script -qec "$1" /dev/null 2>&1 || true
}

motd_shown_by() {
  case "$(motd_on_tty "$1")" in
    *"$MOTD_MARKER"*) return 0 ;;
    *) return 1 ;;
  esac
}

motd_hidden_by() {
  ! motd_shown_by "$1"
}

# Output of shells that are not on a terminal: here stdout is captured, so even
# an interactive shell has to stay silent.
motd_silent_without_tty() {
  local out
  out=$({ zsh -c true; bash -c true; zsh -i -c true < /dev/null; bash -i -c true < /dev/null; } 2>&1 || true)
  case "$out" in
    *"$MOTD_MARKER"*) return 1 ;;
    *) return 0 ;;
  esac
}

# A nested shell inherits the guard, so one session prints the message once.
motd_printed_once() {
  local count
  count=$(motd_on_tty "zsh -i -c 'zsh -i -c true'" | grep -c "$MOTD_MARKER" || true)
  [ "$count" = 1 ]
}

motd_names_image() {
  case "$(motd_on_tty 'zsh -i -c true')" in
    *"$1"*) return 0 ;;
    *) return 1 ;;
  esac
}

# Proxy settings show up, and a login in the URL does not.
motd_shows_proxy_without_login() {
  local out
  out=$(motd_on_tty 'HTTPS_PROXY=http://alice:s3cret@proxy.example:3128 NO_PROXY=a,b,c,d,e zsh -i -c true')
  case "$out" in
    *s3cret* | *alice*) return 1 ;;
  esac
  case "$out" in
    *'proxy.example:3128'*'(+2 more)'*) return 0 ;;
    *) return 1 ;;
  esac
}

# No proxy in the environment, no proxy line: the message lists what is set.
motd_omits_proxy_when_unset() {
  case "$(motd_on_tty 'env -u HTTP_PROXY -u http_proxy -u HTTPS_PROXY -u https_proxy -u NO_PROXY -u no_proxy zsh -i -c true')" in
    *'  proxy '* | *'  no_proxy '*) return 1 ;;
    *) return 0 ;;
  esac
}

motd_hidden_by_hushlogin() {
  local home
  home=$(mktemp -d) || return 1
  # An empty .zshrc keeps zsh from starting its new-user setup wizard.
  : > "${home}/.hushlogin"
  : > "${home}/.zshrc"
  motd_hidden_by "HOME=${home} zsh -i -c true"
  local rc=$?
  rm -rf "$home"
  return "$rc"
}

check_welcome_message() {
  local image="$1"
  echo "${image}: welcome message"
  require_cmd script
  require_run shown-by-zsh motd_shown_by 'zsh -i -c true'
  require_run shown-by-bash motd_shown_by 'bash -i -c true'
  require_run names-the-image motd_names_image "$image"
  require_run silent-without-a-terminal motd_silent_without_tty
  require_run printed-once-per-session motd_printed_once
  require_run proxy-shown-without-login motd_shows_proxy_without_login
  require_run no-proxy-line-when-unset motd_omits_proxy_when_unset
  require_run hidden-by-NO_MOTD motd_hidden_by 'NO_MOTD=1 zsh -i -c true'
  require_run hidden-by-hushlogin motd_hidden_by_hushlogin
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
  local count=0 broken=0 name target dir
  local dirs=()

  for dir in "$MISE_SHIMS" "$MISE_SYSTEM_SHIMS"; do
    [ -d "$dir" ] && dirs+=("$dir")
  done

  if [ "${#dirs[@]}" -eq 0 ]; then
    if [ "$expect" = "optional" ]; then
      printf '  skip     no mise in this image\n'
      return 0
    fi
    printf '  FAILED   no mise shims directory at %s or %s\n' "$MISE_SHIMS" "$MISE_SYSTEM_SHIMS"
    FAILURES=$((FAILURES + 1))
    return 1
  fi

  # A tool can have a shim in both layers; it is one binary to probe.
  while read -r name; do
    [ -n "$name" ] || continue
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
  done < <(for dir in "${dirs[@]}"; do ls -1A "$dir"; done | sort -u)

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

# Every tool the image's mise config pins must be installed. The runner images
# install that config with `mise install --locked`, so this is the check that a
# pinned tool cannot quietly drop out of the image: the shims probe only sees
# what did install, and the declared contract only names a few.
# Read from / so a mise.toml in the working directory cannot add or hide
# anything; what is left is the system and global config, which is where an
# image keeps its pins (gh-runner in /etc/mise, act-runner in ~/.config/mise).
probe_mise_config_installed() {
  command -v mise > /dev/null 2>&1 || {
    printf '  FAILED   mise not installed\n'
    FAILURES=$((FAILURES + 1))
    return 1
  }

  local missing total
  total=$(cd / && mise ls --current 2>/dev/null | awk 'NF' | wc -l | tr -d ' ')
  missing=$(cd / && mise ls --current --missing 2>/dev/null | awk 'NF {print $1 "@" $2}')
  if [ "$total" -eq 0 ]; then
    printf '  FAILED   the mise config pins no tools\n'
    FAILURES=$((FAILURES + 1))
    return 1
  fi
  if [ -n "$missing" ]; then
    while read -r tool; do
      printf '  MISSING  %s (pinned in the mise config, not installed)\n' "$tool"
      FAILURES=$((FAILURES + 1))
    done <<< "$missing"
    return 1
  fi
  printf '  ok       all %s tools pinned in the mise config are installed\n' "$total"
}

report() {
  echo
  if [ "$FAILURES" -gt 0 ]; then
    printf 'FAIL - %s check(s) failed\n' "$FAILURES"
    exit 1
  fi
  printf 'PASS - all checks succeeded\n'
}
