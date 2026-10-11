#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'

# Defaults
# Follows main by default; set TOOLS_REF to a tag or commit SHA to pin what gets installed,
# or RAW_BASE to read from another location (a mirror, a local checkout via file://).
RAW_BASE="${RAW_BASE:-https://raw.githubusercontent.com/this-is-tobi/tools/${TOOLS_REF:-main}}"
TOOL="both"
PRESET="general"
CUSTOM_INSTRUCTIONS=""
WITH_AGENTS=0
WITH_PLUGINS=0
GLOBAL=0
WITH_CLI=0
RTK_MERGE=0
COPILOT_CLI_FILE="${HOME}/.copilot/copilot-instructions.md"
CLAUDE_MARKETPLACE="claude-plugins-official"
CLAUDE_MARKETPLACE_SOURCE="anthropics/claude-plugins-official"
CLAUDE_PLUGINS="claude-security superpowers"
SKILLS="code-review repository-audit commit-message pull-request"
AGENTS="code-reviewer security-auditor refactorer test-writer doc-writer migration-researcher migration-assistant iac-reviewer"
# Read by one Copilot feature through a VS Code setting, never loaded into every chat
FEATURE_INSTRUCTIONS="commit-message pull-request code-review"
GENERAL_HEADING="# General Development Instructions"
BLOCK_BEGIN="<!-- general-instructions"
BLOCK_END="<!-- /general-instructions -->"
MANIFEST=".setup-ai-agent-manifest"
STAMP="$(date +%Y%m%d%H%M%S)"
WORK_DIR=""
PENDING_TMP=""

# Script helper
TEXT_HELPER="
This script handles everything AI coding-agent related for Claude Code and/or GitHub Copilot, from this
repo's ai/common/ and ai/<tool>/ sources — the same content documented in docs/02-ai.md, wired up in one
command instead of copy-pasting each curl. Each piece lands once per tool, in the place that tool reads,
so nothing is loaded twice when both tools (or VS Code, which reads both) are in use.

Available flags:
  -t    Tool to set up: 'claude', 'copilot', or 'both' (default: 'both').
  -p    Instruction preset: 'general', 'javascript', 'python', 'kubernetes', or 'go' (default: 'general').
        Always includes 'general'; presets add the scoped files for that stack.
  -i    Custom comma-separated instruction names, overrides -p (e.g. 'general,docker,terraform').
        'commit-message', 'pull-request' and 'code-review' are per-feature instructions: a repo-level
        Copilot setup puts them in '.github/feature-instructions/' (read through VS Code settings, never
        loaded into a chat); Claude Code uses the skills of the same name instead.
  -a    Also install custom agents (off by default — instructions + skills only).
  -P    Also install Claude Code plugins ('${CLAUDE_PLUGINS}') from the official Anthropic marketplace
        ('${CLAUDE_MARKETPLACE_SOURCE}'). Always user scope, so the plugin is available in every repo
        regardless of -g. Claude Code-only — ignored with -t copilot. Skipped with a warning when the
        'claude' binary isn't on PATH. Idempotent: re-running re-checks the marketplace and updates
        already-installed plugins. The 'systematic-debugging' skill is not installed (and removed if an
        earlier run installed it) while the superpowers plugin, which ships its own, is installed or
        enabled: with -P or in ~/.claude/settings.json for -g, in the repository's .claude/settings.json
        otherwise.
  -g    Personal/global setup (~/.claude, ~/.copilot) instead of repo-level. Claude Code gets only
        'general' in this mode (one personal file, no scoping), whatever -p/-i say.
  -c    Kept for compatibility, no longer needed: with -g, Copilot always gets the general instructions
        in '${COPILOT_CLI_FILE}' (read by Copilot CLI and VS Code alike) as a marked block that is
        replaced on re-runs; everything else in the file (rtk's block, your own content) is left untouched.
  -r    Run 'rtk init -g --copilot' safely instead of setting anything up: saves '${COPILOT_CLI_FILE}' as
        '<file>.bak.<timestamp>', lets rtk write its block, then puts your content back with the new rtk
        block (rtk releases before 0.41.0 overwrite the whole file). Safe to re-run — never duplicates
        the block. Standalone action, ignores every other flag except -h.
  -h    Print script help.

Where things go:
  repo (default)  AGENTS.md (general, marked block), .claude/rules/<name>.md and/or
                  .github/instructions/<name>.instructions.md (scoped), .github/feature-instructions/,
                  .claude/skills (both tools read it) or .github/skills (copilot only), .claude/agents
                  and/or .github/agents.
  personal (-g)   ~/.claude/general-instructions.md (imported by ~/.claude/CLAUDE.md), ~/.claude/skills,
                  ~/.claude/agents; ~/.copilot/copilot-instructions.md (marked block),
                  ~/.copilot/instructions (scoped), ~/.copilot/skills, ~/.copilot/agents.

Each of .claude/, .github/, ~/.claude/ and ~/.copilot/ keeps a '${MANIFEST}' file listing what this
script installed there. A file you edited since is kept as '<name>.bak.<timestamp>' before it is replaced
or removed; skills and agents this script installed and no longer ships are removed; files it did not
install are never replaced or removed (in AGENTS.md, CLAUDE.md and copilot-instructions.md it only keeps
its marked block or import line). Set TOOLS_REF=<tag|sha> to pin the source,
RAW_BASE=file:///path/to/checkout to install from a local checkout.

Examples:
  ./setup-ai-agent.sh -t claude
  ./setup-ai-agent.sh -t copilot -p javascript -a
  ./setup-ai-agent.sh -t both -g
  ./setup-ai-agent.sh -t claude -g -P
  ./setup-ai-agent.sh -t copilot -g
  ./setup-ai-agent.sh -r
"

# Functions
print_help() {
  printf '%s\n' "$TEXT_HELPER"
}

note() {
  printf "${COLOR_BLUE}Note${COLOR_OFF}: %s\n" "$*"
}

warn() {
  printf "${COLOR_RED}Warning${COLOR_OFF}: %s\n" "$*"
}

fail() {
  printf "${COLOR_RED}Error${COLOR_OFF}: %s\n" "$*" >&2
  exit 1
}

cleanup() {
  if [ -n "$PENDING_TMP" ]; then
    rm -f "$PENDING_TMP"
  fi
  if [ -n "$WORK_DIR" ]; then
    rm -rf "$WORK_DIR"
  fi
}

has_word() {
  case " $2 " in
    *" $1 "*) return 0;;
  esac
  return 1
}

# Fingerprint used to tell a file left as this script installed it from one edited since.
checksum() {
  cksum < "$1" | awk '{ print $1 "-" $2 }'
}

first_heading() {
  awk '/^# / { print; exit }' "$1"
}

# Drop a leading YAML frontmatter block (Copilot's applyTo) and the blank lines after it: it is
# meaningless once the text is inlined into a Claude Code file or read through a VS Code setting.
strip_frontmatter() {
  awk 'NR == 1 && $0 == "---" { skip = 1; next }
       skip && $0 == "---" { skip = 0; next }
       skip { next }
       !body && $0 == "" { next }
       { body = 1; print }'
}

# Turn a Copilot instructions file into a Claude Code rule: the applyTo glob becomes a paths entry,
# so the rule still only loads for matching files (a YAML list, as a brace glob holds commas).
to_claude_rule() {
  awk 'NR == 1 && $0 == "---" { fm = 1; print; next }
       fm && $0 == "---" { fm = 0; print; next }
       fm && sub(/^applyTo:[ \t]*/, "") { print "paths:"; print "  - " $0; next }
       { print }'
}

# fetch_src <path under RAW_BASE>: download one source file into the work directory, once.
# Every source is fetched before anything is written, so a failed download changes nothing.
fetch_src() {
  local dest="${WORK_DIR}/src/$1"
  if [ -f "$dest" ]; then
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if ! curl -fsSL "${RAW_BASE}/$1" -o "$dest"; then
    rm -f "$dest"
    fail "could not download ${RAW_BASE}/$1"
  fi
}

src() {
  printf '%s' "${WORK_DIR}/src/$1"
}

# commit_file <src> <dest>: put <src> at <dest> (mode 644) through a temporary file renamed in the
# destination directory, so an interrupted run never leaves a truncated file. No-op when identical;
# a symlink (an AGENTS.md linked to CLAUDE.md, say) is written through rather than replaced.
commit_file() {
  local from="$1" dest="$2" tmp
  if [ -f "$dest" ] && cmp -s "$from" "$dest"; then
    return 0
  fi
  if [ -L "$dest" ]; then
    cat "$from" > "$dest" || fail "could not write '${dest}'"
    return 0
  fi
  tmp="$(mktemp "${dest}.XXXXXX")"
  PENDING_TMP="$tmp"
  # An existing file keeps its mode (cp -p, then overwrite the content); a new one gets 644
  if [ -f "$dest" ]; then
    cp -p "$dest" "$tmp" || fail "could not write '${dest}'"
  else
    chmod 644 "$tmp"
  fi
  if ! { cat "$from" > "$tmp" && mv -f "$tmp" "$dest"; }; then
    fail "could not write '${dest}'"
  fi
  PENDING_TMP=""
}

# backup_name <file>: '<file>.bak.<timestamp>', with a counter when a run in the same second made one.
backup_name() {
  local saved="${1}.bak.${STAMP}" n=1
  while [ -e "$saved" ]; do
    saved="${1}.bak.${STAMP}.${n}"
    n=$((n + 1))
  done
  printf '%s' "$saved"
}

backup() {
  local saved
  # In a repository, git already keeps a committed file that has no local change
  if [ "$GLOBAL" = "0" ] && git ls-files --error-unmatch -- "$1" > /dev/null 2>&1 \
    && git diff --quiet HEAD -- "$1" 2> /dev/null; then
    return 0
  fi
  saved="$(backup_name "$1")"
  cp -p "$1" "$saved"
  note "kept your previous '$1' as '${saved}'."
}

# Each install root (~/.claude, ~/.copilot, .claude, .github) keeps a manifest of '<checksum> <path>'
# lines for the files this script put there. The checksum tells a file left as installed (replaced
# or removed silently) from one edited since (backed up first); the list tells what this script
# installed (pruned once no longer shipped) from what the user created (never touched).
manifest_open() {
  ROOT="$1"
  mkdir -p "$ROOT"
  OLD_MANIFEST="${ROOT}/${MANIFEST}"
  NEW_MANIFEST="$(mktemp "${WORK_DIR}/manifest.XXXXXX")"
}

recorded_sum() {
  if [ -f "$OLD_MANIFEST" ]; then
    awk -v p="$1" '$2 == p { print $1; exit }' "$OLD_MANIFEST"
  fi
}

# install_file <src> <path under root>: a destination that differs, and that was edited since this
# script installed it (or that it never installed), is backed up before it is replaced.
install_file() {
  local from="$1" rel="$2" dest="${ROOT}/$2" recorded
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ] && ! cmp -s "$from" "$dest"; then
    recorded="$(recorded_sum "$rel")"
    if [ -z "$recorded" ] && [ "$(first_heading "$dest")" != "$(first_heading "$from")" ]; then
      warn "left '${dest}' alone: it is not a file this script installed (another heading than the shipped one). Move or remove it to have the shipped version."
      return 0
    fi
    if [ -z "$recorded" ] || [ "$(checksum "$dest")" != "$recorded" ]; then
      backup "$dest"
    fi
  fi
  commit_file "$from" "$dest"
  printf '%s %s\n' "$(checksum "$dest")" "$rel" >> "$NEW_MANIFEST"
}

# drop <file> <checksum recorded at install, or empty>: remove a file this script installed, backed
# up first unless it is still exactly what was installed. An emptied skill folder goes too.
drop() {
  local path="$1" recorded="$2"
  if [ ! -f "$path" ]; then
    return 0
  fi
  if [ -z "$recorded" ] || [ "$(checksum "$path")" != "$recorded" ]; then
    backup "$path"
  fi
  rm -f "$path"
  case "$path" in
    */skills/*/SKILL.md) rmdir "$(dirname "$path")" 2> /dev/null || true;;
  esac
  note "removed '${path}', which this script no longer installs there."
}

# retire <file> <path under root, or empty> <heading>: remove a file an earlier run put where the
# current layout no longer installs it (it would be loaded twice otherwise). It is ours when the
# manifest lists it, or, from a run that predates the manifest, when its first heading is the one
# of the file shipped there. Anything else belongs to the user and stays.
retire() {
  local path="$1" rel="$2" heading="$3" recorded=""
  if [ ! -f "$path" ]; then
    return 0
  fi
  if [ -n "$rel" ]; then
    recorded="$(recorded_sum "$rel")"
  fi
  if [ -z "$recorded" ] && [ "$(first_heading "$path")" != "$heading" ]; then
    warn "left '${path}' alone: this script did not install it, but it may duplicate what it just installed."
    return 0
  fi
  drop "$path" "$recorded"
}

in_new_manifest() {
  awk -v p="$1" '$2 == p { found = 1 } END { exit !found }' "$NEW_MANIFEST"
}

# manifest_close <managed prefixes...>: remove what this script installed under a prefix it fully
# manages this run (skills always, agents with -a) and did not install again; keep the other records.
manifest_close() {
  local sum rel prefix managed
  if [ -f "$OLD_MANIFEST" ]; then
    while read -r sum rel; do
      if [ -z "$rel" ] || in_new_manifest "$rel"; then
        continue
      fi
      case "$rel" in
        */../*|../*|*/..|/*|*[!A-Za-z0-9._/-]*)
          warn "ignored the manifest entry '${rel}' in '${OLD_MANIFEST}': not a path inside '${ROOT}'."
          continue;;
      esac
      managed=0
      for prefix in "$@"; do
        case "$rel" in
          "$prefix"*) managed=1;;
        esac
      done
      if [ "$managed" = "1" ]; then
        drop "${ROOT}/${rel}" "$sum"
      elif [ -f "${ROOT}/${rel}" ]; then
        printf '%s %s\n' "$sum" "$rel" >> "$NEW_MANIFEST"
      fi
    done < "$OLD_MANIFEST"
  fi
  if [ -s "$NEW_MANIFEST" ]; then
    commit_file "$NEW_MANIFEST" "$OLD_MANIFEST"
  else
    rm -f "$OLD_MANIFEST"
  fi
}

# write_block <file> <body>: keep <body> in <file> between the general-instructions markers. A
# previous block is replaced in place (a second copy is dropped), everything else is left as is, and
# an unterminated block is never treated as one. The begin marker records the block's checksum, so a
# block edited by hand is noticed and the whole file backed up before it is replaced.
write_block() {
  local file="$1" body="$2" input="$1" sum block result old_head old_body old_sum
  sum="$(checksum "$body")"
  block="${WORK_DIR}/block.md"
  result="${WORK_DIR}/block-result.md"
  old_head="${WORK_DIR}/block-old-head"
  old_body="${WORK_DIR}/block-old-body"
  {
    printf '%s %s -->\n' "$BLOCK_BEGIN" "$sum"
    cat "$body"
    printf '%s\n' "$BLOCK_END"
  } > "$block"
  rm -f "$old_head" "$old_body"
  mkdir -p "$(dirname "$file")"
  [ -f "$file" ] || input="/dev/null"

  awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" -v hf="$old_head" -v bf="$old_body" '
    { line = $0; sub(/\r$/, "", line) }
    index(line, b) == 1 { inblock = 1; head = line; n = 0; next }
    inblock && line == e { found = 1; exit }
    inblock { lines[++n] = $0 }
    END {
      if (found) {
        print head > hf
        printf "" > bf
        for (i = 1; i <= n; i++) print lines[i] > bf
      }
    }' "$input"

  if [ "$(grep -c "^${BLOCK_BEGIN}" "$input" || true)" -gt 1 ]; then
    backup "$file"
  fi
  if [ -f "$old_head" ]; then
    old_sum="$(sed -n 's/^<!-- general-instructions \([0-9-]*\) -->$/\1/p' "$old_head")"
    if ! cmp -s "$old_body" "$body" && { [ -z "$old_sum" ] || [ "$(checksum "$old_body")" != "$old_sum" ]; }; then
      backup "$file"
    fi
  elif grep -q "^${GENERAL_HEADING}"'\r*$' "$input"; then
    warn "'${file}' already holds an unmarked copy of the general instructions from an older run; remove it by hand so it is not loaded twice."
  fi

  awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" -v blk="$block" '
    function flush(   i) { for (i = 1; i <= n; i++) print buf[i]; n = 0 }
    function emit(   l) {
      if (done) return
      while ((getline l < blk) > 0) print l
      close(blk)
      done = 1
    }
    { line = $0; sub(/\r$/, "", line) }
    index(line, b) == 1 { if (inblock) flush(); inblock = 1; buf[++n] = $0; next }
    inblock { buf[++n] = $0; if (line == e) { inblock = 0; n = 0; emit() } next }
    { print; seen = 1 }
    END {
      if (inblock) flush()
      if (!done) { if (seen) print ""; emit() }
    }' "$input" > "$result"
  commit_file "$result" "$file"
}

# rtk marks its block '<!-- rtk-instructions vN -->' ... '<!-- /rtk-instructions -->'; match any
# version. strip_rtk_block drops complete blocks, extract_rtk_block prints the first one.
strip_rtk_block() {
  awk '
    function flush(   i) { for (i = 1; i <= n; i++) print buf[i]; n = 0 }
    /^[ \t]*<!-- rtk-instructions/ { flush(); inblock = 1; buf[++n] = $0; next }
    inblock { buf[++n] = $0; if ($0 ~ /^[ \t]*<!-- \/rtk-instructions -->[ \t\r]*$/) { inblock = 0; n = 0 } next }
    { print }
    END { flush() }'
}

extract_rtk_block() {
  awk '
    /^[ \t]*<!-- rtk-instructions/ { inblock = 1; n = 0 }
    inblock { buf[++n] = $0 }
    inblock && /^[ \t]*<!-- \/rtk-instructions -->[ \t\r]*$/ { for (i = 1; i <= n; i++) print buf[i]; exit }'
}

merge_rtk_copilot() {
  local saved="" custom="" block merged
  if ! command -v rtk > /dev/null 2>&1; then
    fail "'rtk' binary not found. Install it first: https://github.com/rtk-ai/rtk"
  fi
  mkdir -p "$(dirname "$COPILOT_CLI_FILE")"

  if [ -s "$COPILOT_CLI_FILE" ]; then
    saved="$(backup_name "$COPILOT_CLI_FILE")"
    cp -p "$COPILOT_CLI_FILE" "$saved"
    printf "${COLOR_BLUE}Backed up${COLOR_OFF} '%s' to '%s'.\n" "$COPILOT_CLI_FILE" "$saved"
    # Any rtk block from a previous run is dropped so re-running never duplicates it
    custom="$(strip_rtk_block < "$saved")"
  fi

  printf "${COLOR_BLUE}Running${COLOR_OFF} 'rtk init -g --copilot'...\n"
  if ! rtk init -g --copilot; then
    fail "'rtk init -g --copilot' failed; '${COPILOT_CLI_FILE}' is as rtk left it${saved:+, your previous content is in '${saved}'}."
  fi

  block="$([ -f "$COPILOT_CLI_FILE" ] && extract_rtk_block < "$COPILOT_CLI_FILE" || true)"
  if [ -z "$block" ]; then
    fail "rtk did not write its block to '${COPILOT_CLI_FILE}'; the file is as rtk left it${saved:+, your previous content is in '${saved}'}."
  fi

  merged="${WORK_DIR}/copilot-instructions.md"
  {
    if [ -n "$(printf '%s' "$custom" | tr -d '[:space:]')" ]; then
      printf '%s\n\n' "$custom"
    fi
    printf '%s\n' "$block"
  } > "$merged"
  commit_file "$merged" "$COPILOT_CLI_FILE"

  if [ -n "$saved" ] && cmp -s "$saved" "$COPILOT_CLI_FILE"; then
    rm -f "$saved"
    printf "${COLOR_GREEN}Done${COLOR_OFF}: '%s' already had the current RTK block, nothing changed.\n" "$COPILOT_CLI_FILE"
  elif [ -n "$(printf '%s' "$custom" | tr -d '[:space:]')" ]; then
    printf "${COLOR_GREEN}Done${COLOR_OFF}: '%s' now has your custom instructions plus the current RTK block.\n" "$COPILOT_CLI_FILE"
  else
    printf "${COLOR_GREEN}Done${COLOR_OFF}: no existing custom content found, '%s' now has the current RTK block only.\n" "$COPILOT_CLI_FILE"
  fi
}

resolve_instructions() {
  local names name
  if [ -n "$CUSTOM_INSTRUCTIONS" ]; then
    names="$(printf '%s' "$CUSTOM_INSTRUCTIONS" | tr ',' ' ')"
  else
    case "$PRESET" in
      javascript) names="general javascript docker github-actions";;
      python)     names="general python docker github-actions";;
      kubernetes) names="general kubernetes docker github-actions terraform shell";;
      go)         names="general go docker github-actions";;
      general)    names="general";;
      *)          fail "invalid -p value '${PRESET}' (expected 'general', 'javascript', 'python', 'kubernetes' or 'go').";;
    esac
  fi
  # Names become download URLs and file names
  local unique=""
  for name in $names; do
    case "$name" in
      -*|*[!A-Za-z0-9_-]*) fail "invalid instruction name '${name}' (letters, digits, '-' and '_' only, not starting with '-').";;
    esac
    has_word "$name" "$unique" || unique="${unique:+${unique} }${name}"
  done
  printf '%s' "$unique"
}

# The superpowers plugin ships its own systematic-debugging skill, with the same trigger. Personal
# setup follows your plugins (-P, ~/.claude/settings.json); a repository follows its own
# .claude/settings.json only, so the result does not depend on who runs the script.
superpowers_present() {
  local settings=".claude/settings.json"
  if [ "$GLOBAL" = "1" ]; then
    settings="${HOME}/.claude/settings.json"
    if [ "$WITH_PLUGINS" = "1" ] && has_word superpowers "$CLAUDE_PLUGINS" && command -v claude > /dev/null 2>&1; then
      return 0
    fi
  fi
  [ -f "$settings" ] && grep -Eq '"superpowers@[^"]*"[[:space:]]*:[[:space:]]*true' "$settings"
}

prefetch() {
  local name skill agent
  fetch_src "ai/common/instructions/general.instructions.md"
  for name in $INSTRUCTIONS; do
    fetch_src "ai/common/instructions/${name}.instructions.md"
  done
  for skill in $SKILLS; do
    fetch_src "ai/common/skills/${skill}/SKILL.md"
  done
  if [ "$TOOL" != "copilot" ]; then
    fetch_src "ai/claude/skills/systematic-debugging/SKILL.md"
  fi
  if [ "$WITH_AGENTS" = "1" ]; then
    for agent in $AGENTS; do
      [ "$TOOL" = "copilot" ] || fetch_src "ai/claude/agents/${agent}.md"
      [ "$TOOL" = "claude" ] || fetch_src "ai/copilot/agents/${agent}.md"
    done
  fi
}

# The general instructions without their frontmatter, shared by every always-on copy.
general_body() {
  local body="${WORK_DIR}/general.md"
  if [ ! -f "$body" ]; then
    strip_frontmatter < "$(src ai/common/instructions/general.instructions.md)" > "$body"
  fi
  printf '%s' "$body"
}

# Repository: AGENTS.md is the one always-on file every tool reads (Claude Code when no CLAUDE.md
# exists, Copilot in VS Code, on the CLI and on GitHub, Codex).
setup_agents_md() {
  write_block "AGENTS.md" "$(general_body)"
  printf "${COLOR_GREEN}AGENTS.md${COLOR_OFF}: general instructions up to date.\n"
}

# Claude Code reads AGENTS.md only while no CLAUDE.md exists; otherwise CLAUDE.md has to import it.
link_claude_md() {
  local file import
  # A CLAUDE.md written by older runs holds a second copy of the instructions
  if [ -f "CLAUDE.md" ] && [ ! -L "CLAUDE.md" ] && [ "$(first_heading "CLAUDE.md")" = "$GENERAL_HEADING" ]; then
    retire "CLAUDE.md" "" "$GENERAL_HEADING"
  fi
  for file in CLAUDE.md .claude/CLAUDE.md; do
    if [ -f "$file" ] && [ "$file" -ef "AGENTS.md" ]; then
      # One is a symlink to the other: Claude Code already reads the shared file
      return 0
    elif [ -f "$file" ]; then
      import="@AGENTS.md"
      [ "$file" = "CLAUDE.md" ] || import="@../AGENTS.md"
      if ! grep -qxF "$import" "$file"; then
        printf '\n%s\n' "$import" >> "$file"
        note "added '${import}' to '${file}': Claude Code reads CLAUDE.md instead of AGENTS.md when both exist."
      fi
      return 0
    fi
  done
  if [ -f "CLAUDE.local.md" ]; then
    note "'CLAUDE.local.md' stops Claude Code from reading AGENTS.md: add '@AGENTS.md' to it."
  else
    note "Claude Code reads AGENTS.md by itself from v2.1.277 on; on older versions run: echo '@AGENTS.md' > CLAUDE.md"
  fi
}

install_claude_skills() {
  local skill
  for skill in $SKILLS; do
    install_file "$(src "ai/common/skills/${skill}/SKILL.md")" "skills/${skill}/SKILL.md"
  done
  if superpowers_present; then
    retire "${ROOT}/skills/systematic-debugging/SKILL.md" "skills/systematic-debugging/SKILL.md" "# Systematic Debugging"
    note "'systematic-debugging' not installed: the superpowers plugin provides its own."
  else
    install_file "$(src ai/claude/skills/systematic-debugging/SKILL.md)" "skills/systematic-debugging/SKILL.md"
  fi
}

setup_claude() {
  local instructions="$1" name rule managed="skills/" copies=""
  printf "${COLOR_BLUE}Setting up Claude Code${COLOR_OFF} (%s)...\n" "$([ "$GLOBAL" = "1" ] && echo personal || echo repo)"

  if [ "$GLOBAL" = "1" ]; then
    manifest_open "${HOME}/.claude"
    install_file "$(general_body)" "general-instructions.md"
    # VS Code also reads ~/.claude/CLAUDE.md but does not expand '@' imports, so this copy never
    # doubles the one Copilot gets from ~/.copilot/copilot-instructions.md
    [ -f "${HOME}/.claude/CLAUDE.md" ] || : > "${HOME}/.claude/CLAUDE.md"
    grep -qxF '@general-instructions.md' "${HOME}/.claude/CLAUDE.md" || \
      printf '\n%s\n' '@general-instructions.md' >> "${HOME}/.claude/CLAUDE.md"
  else
    manifest_open ".claude"
    link_claude_md
    for name in $instructions; do
      if [ "$name" = "general" ]; then
        continue
      elif has_word "$name" "$FEATURE_INSTRUCTIONS"; then
        note "'${name}' skipped for Claude Code: the '${name}' skill covers it, a rule would load it in every session."
        continue
      fi
      rule="${WORK_DIR}/rule-${name}.md"
      to_claude_rule < "$(src "ai/common/instructions/${name}.instructions.md")" > "$rule"
      install_file "$rule" "rules/${name}.md"
      [ ! -f ".github/instructions/${name}.instructions.md" ] || copies="${copies} .github/instructions/${name}.instructions.md"
    done
  fi

  install_claude_skills

  if [ "$WITH_AGENTS" = "1" ]; then
    managed="skills/ agents/"
    for name in $AGENTS; do
      install_file "$(src "ai/claude/agents/${name}.md")" "agents/${name}.md"
    done
  fi

  # shellcheck disable=SC2086 # one argument per managed prefix
  manifest_close $managed

  if [ "$GLOBAL" = "0" ] && [ "$TOOL" = "claude" ]; then
    for name in $SKILLS; do
      [ ! -f ".github/skills/${name}/SKILL.md" ] || copies="${copies} .github/skills/${name}/SKILL.md"
    done
    if [ -n "$copies" ]; then
      note "Copilot CLI and VS Code read the .claude/ copies too, so these are now loaded twice:${copies}. Run with -t both (or -t copilot) to remove the ones this script installed."
    fi
  fi
  if [ "$TOOL" = "claude" ]; then
    agents_note
  fi
  printf "${COLOR_GREEN}Claude Code setup done.${COLOR_OFF}\n"
}

setup_claude_plugins() {
  local plugin
  if ! command -v claude > /dev/null 2>&1; then
    printf "${COLOR_RED}Warning${COLOR_OFF}: 'claude' binary not found — skipping plugin install (-P).\n"
    return 0
  fi

  printf "${COLOR_BLUE}Installing Claude Code plugins${COLOR_OFF} (user scope)...\n"
  claude plugin marketplace add "$CLAUDE_MARKETPLACE_SOURCE" > /dev/null

  for plugin in $CLAUDE_PLUGINS; do
    # 'install' is a no-op once the plugin is present, so 'update' is what keeps re-runs current
    claude plugin install "${plugin}@${CLAUDE_MARKETPLACE}" -s user
    claude plugin update "${plugin}@${CLAUDE_MARKETPLACE}"
  done

  printf "${COLOR_GREEN}Claude Code plugins done.${COLOR_OFF}\n"
  printf "${COLOR_BLUE}Note${COLOR_OFF}: plugin state lives in '~/.claude/settings.json' (enabledPlugins + extraKnownMarketplaces) — anything that overwrites that file wholesale drops it. Run '/reload-plugins' to activate in an already-open session.\n"
}

# copilot_item <source> <path under root> <path under .claude, or empty>: install one Copilot file,
# unless this script installed the Claude Code copy in the repository, which Copilot CLI and VS Code
# read as well: then a copy installed in .github/ by an earlier run is removed instead, so the
# content is loaded once.
copilot_item() {
  local from="$1" rel="$2" claude_rel="$3" claude_copy=".claude/$3"
  if [ -n "$claude_rel" ] && [ -e "$claude_copy" ] && [ "${ROOT}/${rel}" -ef "$claude_copy" ]; then
    # .github/<folder> is a link to .claude/<folder>: nothing to install or remove
    SHARED="${SHARED} ${claude_copy}"
  elif [ -n "$claude_rel" ] && [ -f "$claude_copy" ] && [ -f ".claude/${MANIFEST}" ] \
    && awk -v p="$claude_rel" '$2 == p { found = 1 } END { exit !found }' ".claude/${MANIFEST}"; then
    retire "${ROOT}/${rel}" "$rel" "$(first_heading "$from")"
    SHARED="${SHARED} ${claude_copy}"
  else
    install_file "$from" "$rel"
  fi
}

setup_copilot() {
  local instructions="$1" name body managed="skills/" features="" claude_dir=""
  printf "${COLOR_BLUE}Setting up GitHub Copilot${COLOR_OFF} (%s)...\n" "$([ "$GLOBAL" = "1" ] && echo personal || echo repo)"
  SHARED=""

  if [ "$GLOBAL" = "1" ]; then
    manifest_open "${HOME}/.copilot"
    # Copilot CLI and VS Code both read this file in every session: the one personal copy
    write_block "$COPILOT_CLI_FILE" "$(general_body)"
  else
    manifest_open ".github"
    claude_dir=".claude"
  fi
  # The general instructions now live in AGENTS.md (repo) or copilot-instructions.md (personal)
  retire "${ROOT}/instructions/general.instructions.md" "instructions/general.instructions.md" "$GENERAL_HEADING"

  for name in $instructions; do
    if [ "$name" = "general" ]; then
      continue
    fi
    if has_word "$name" "$FEATURE_INSTRUCTIONS"; then
      # Older runs put them in an instructions folder, where applyTo "**" loads them into every chat
      retire "${ROOT}/instructions/${name}.instructions.md" "instructions/${name}.instructions.md" \
        "$(first_heading "$(src "ai/common/instructions/${name}.instructions.md")")"
      if [ "$GLOBAL" = "1" ]; then
        features="${features} ${name}"
      else
        body="${WORK_DIR}/feature-${name}.md"
        strip_frontmatter < "$(src "ai/common/instructions/${name}.instructions.md")" > "$body"
        install_file "$body" "feature-instructions/${name}.md"
      fi
      continue
    fi
    copilot_item "$(src "ai/common/instructions/${name}.instructions.md")" "instructions/${name}.instructions.md" \
      "${claude_dir:+rules/${name}.md}"
  done

  for name in $SKILLS; do
    copilot_item "$(src "ai/common/skills/${name}/SKILL.md")" "skills/${name}/SKILL.md" \
      "${claude_dir:+skills/${name}/SKILL.md}"
  done

  if [ "$WITH_AGENTS" = "1" ]; then
    managed="skills/ agents/"
    if [ "${ROOT}/agents" -ef "$(dirname "${ROOT}")/.claude/agents" ] 2> /dev/null; then
      warn "'${ROOT}/agents' is the same folder as the Claude Code one: Copilot agents not installed (the formats differ)."
    else
      for name in $AGENTS; do
        install_file "$(src "ai/copilot/agents/${name}.md")" "agents/${name}.md"
      done
    fi
  fi

  # shellcheck disable=SC2086 # one argument per managed prefix
  manifest_close $managed

  if [ -n "$SHARED" ]; then
    note "Copilot uses the Claude Code copies already in this repository (Copilot CLI and VS Code read .claude/rules and .claude/skills):${SHARED}"
  fi
  if [ -n "$features" ]; then
    note "${features# } not installed: VS Code reads the 'file' of its per-feature instruction settings inside each workspace folder, so a personal file cannot be used. Run this script in the repository, or use a 'text' entry (see docs/02-ai.md)."
  fi
  agents_note
  printf "${COLOR_GREEN}GitHub Copilot setup done.${COLOR_OFF}\n"
}

# Agents need one file per tool (the tool names differ), and VS Code lists both folders.
agents_note() {
  local prefix="" home="." first="${AGENTS%% *}" copilot_dir=".github"
  if [ "$GLOBAL" = "1" ]; then
    # shellcheck disable=SC2088 # shown to the user, not expanded
    prefix="~/"
    home="$HOME"
    copilot_dir=".copilot"
  fi
  if [ "$WITH_AGENTS" = "1" ] && [ -f "${home}/.claude/agents/${first}.md" ] && [ -f "${home}/${copilot_dir}/agents/${first}.md" ]; then
    note "the agents exist for both tools (${prefix}.claude/agents, ${prefix}${copilot_dir}/agents) and VS Code's Local agent lists both: set \"chat.agentFilesLocations\": { \"${prefix}.claude/agents\": false } in VS Code to list them once."
  fi
}

main() {
  # Parse options
  local OPTIND=1
  while getopts t:p:i:acgPrh flag "$@"
  do
    case "${flag}" in
      t)
        TOOL="${OPTARG}";;
      p)
        PRESET="${OPTARG}";;
      i)
        CUSTOM_INSTRUCTIONS="${OPTARG}";;
      a)
        WITH_AGENTS=1;;
      P)
        WITH_PLUGINS=1;;
      c)
        WITH_CLI=1;;
      g)
        GLOBAL=1;;
      r)
        RTK_MERGE=1;;
      h)
        print_help
        exit 0;;
      *)
        print_help >&2
        exit 1;;
    esac
  done

  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/setup-ai-agent.XXXXXX")"
  trap cleanup EXIT

  if [ "$RTK_MERGE" = "1" ]; then
    merge_rtk_copilot
    exit 0
  fi

  case "$TOOL" in
    claude|copilot|both) ;;
    *)
      fail "invalid -t value '${TOOL}' (expected 'claude', 'copilot', or 'both').";;
  esac

  if [ "$WITH_CLI" = "1" ]; then
    if [ "$GLOBAL" = "0" ]; then
      printf "${COLOR_RED}Warning${COLOR_OFF}: -c only applies with -g (personal setup) — ignoring it for this repo-level run.\n"
    elif [ "$TOOL" != "claude" ]; then
      note "-c is no longer needed: -g always puts the general instructions in '${COPILOT_CLI_FILE}'."
    fi
  fi

  if [ "$WITH_PLUGINS" = "1" ] && [ "$TOOL" = "copilot" ]; then
    printf "${COLOR_RED}Warning${COLOR_OFF}: -P is Claude Code-only — ignoring it for this '-t copilot' run.\n"
    WITH_PLUGINS=0
  fi

  INSTRUCTIONS="$(resolve_instructions)"
  prefetch

  if [ "$GLOBAL" = "0" ]; then
    setup_agents_md
  fi
  if [ "$TOOL" = "claude" ] || [ "$TOOL" = "both" ]; then
    # Plugins first: whether superpowers is there decides if systematic-debugging is installed
    if [ "$WITH_PLUGINS" = "1" ]; then
      setup_claude_plugins
    fi
    setup_claude "$INSTRUCTIONS"
  fi
  if [ "$TOOL" = "copilot" ] || [ "$TOOL" = "both" ]; then
    setup_copilot "$INSTRUCTIONS"
  fi
}

main "$@"
