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

# Script helper
TEXT_HELPER="
This script handles everything AI coding-agent related for Claude Code and/or GitHub Copilot, from this
repo's ai/common/ and ai/<tool>/ sources — the same content documented in docs/02-ai.md, wired up in one
command instead of copy-pasting each curl.

Available flags:
  -t    Tool to set up: 'claude', 'copilot', or 'both' (default: 'both').
  -p    Instruction preset: 'general', 'javascript', 'python', 'kubernetes', or 'go' (default: 'general').
        Always includes 'general'; presets add the scoped files for that stack.
  -i    Custom comma-separated instruction names, overrides -p (e.g. 'general,docker,terraform').
  -a    Also install custom agents (off by default — instructions + skills only).
  -P    Also install Claude Code plugins ('${CLAUDE_PLUGINS}') from the official Anthropic marketplace
        ('${CLAUDE_MARKETPLACE_SOURCE}'). Always user scope, so the plugin is available in every repo
        regardless of -g. Claude Code-only — ignored with -t copilot. Skipped with a warning when the
        'claude' binary isn't on PATH. Idempotent: re-running re-checks the marketplace and updates
        already-installed plugins.
  -g    Personal/global setup (~/.claude, ~/.copilot) instead of repo-level. Claude Code gets only
        'general' in this mode (one personal file, no scoping), whatever -p/-i say.
  -c    Also populate Copilot CLI's personal file (~/.copilot/copilot-instructions.md), always just
        'general' regardless of -p/-i (matches how Copilot CLI's personal setup works — one always-loaded
        file, no per-repo scoping). The instructions go in a marked block that is replaced on re-runs;
        everything else in the file (rtk's block, your own content) is left untouched. Only applies with
        -g and -t copilot/both; ignored otherwise.
  -r    Run 'rtk init -g --copilot' safely instead of setting anything up: backs up whatever is already in
        '${COPILOT_CLI_FILE}', lets rtk regenerate its block, then merges the two back together (rtk's own
        installer overwrites that file entirely otherwise). Safe to re-run — never duplicates the block.
        Standalone action, ignores every other flag except -h.
  -h    Print script help.

Files this script replaces (instruction files, CLAUDE.md) are first kept next to the original as
'<name>.bak.<timestamp>' when their content differs. Set TOOLS_REF=<tag|sha> to pin the source.

Examples:
  ./setup-ai-agent.sh -t claude
  ./setup-ai-agent.sh -t copilot -p javascript -a
  ./setup-ai-agent.sh -t both -g
  ./setup-ai-agent.sh -t claude -g -P
  ./setup-ai-agent.sh -t copilot -g -c
  ./setup-ai-agent.sh -r
"

# Functions
print_help() {
  printf '%s\n' "$TEXT_HELPER"
}

# Drop a leading YAML frontmatter block (Copilot's applyTo/description): it is meaningless
# once the text is inlined into a Claude Code file.
strip_frontmatter() {
  awk 'NR == 1 && $0 == "---" { skip = 1; next } skip && $0 == "---" { skip = 0; next } !skip { print }'
}

# place <tmp> <dest> <backup>: move a finished temporary file to its destination (mode 644).
# With backup=1, an existing destination whose content differs is kept as <dest>.bak.<timestamp>.
place() {
  local tmp="$1" dest="$2" backup="${3:-0}" saved
  if [ "$backup" = "1" ] && [ -f "$dest" ] && ! cmp -s "$tmp" "$dest"; then
    saved="${dest}.bak.$(date +%Y%m%d%H%M%S)"
    cp -p "$dest" "$saved"
    printf "${COLOR_BLUE}Note${COLOR_OFF}: kept your previous '%s' as '%s'.\n" "$dest" "$saved"
  fi
  chmod 644 "$tmp"
  mv "$tmp" "$dest"
}

# fetch <path under RAW_BASE> <dest> [--strip] [--backup]
# Downloads to a temporary file in the destination directory and renames it, so an
# interrupted download never leaves a truncated file behind.
fetch() {
  local path="$1" dest="$2" strip=0 backup=0 tmp
  shift 2
  for option in "$@"; do
    case "$option" in
      --strip) strip=1;;
      --backup) backup=1;;
    esac
  done
  tmp="$(mktemp "${dest}.XXXXXX")"
  if ! curl -fsSL "${RAW_BASE}/${path}" -o "$tmp"; then
    rm -f "$tmp"
    printf "${COLOR_RED}Error${COLOR_OFF}: could not download %s\n" "${RAW_BASE}/${path}" >&2
    return 1
  fi
  if [ "$strip" = "1" ]; then
    strip_frontmatter < "$tmp" > "${tmp}.body"
    mv "${tmp}.body" "$tmp"
  fi
  place "$tmp" "$dest" "$backup"
}

resolve_instructions() {
  if [ -n "$CUSTOM_INSTRUCTIONS" ]; then
    echo "$CUSTOM_INSTRUCTIONS" | tr ',' ' '
    return
  fi
  case "$PRESET" in
    javascript) echo "general javascript docker github-actions";;
    python)     echo "general python docker github-actions";;
    kubernetes) echo "general kubernetes docker github-actions terraform shell";;
    go)         echo "general go docker github-actions";;
    general|*)  echo "general";;
  esac
}

merge_rtk_copilot() {
  if ! command -v rtk > /dev/null 2>&1; then
    printf "${COLOR_RED}Error${COLOR_OFF}: 'rtk' binary not found. Install it first: https://github.com/rtk-ai/rtk\n"
    exit 1
  fi

  local custom_content=""
  if [ -f "$COPILOT_CLI_FILE" ]; then
    printf "${COLOR_BLUE}Backing up${COLOR_OFF} existing content from '${COPILOT_CLI_FILE}'...\n"
    # Strip any RTK block from a previous run so re-running this stays idempotent
    custom_content="$(sed '/<!-- rtk-instructions v2 -->/,/<!-- \/rtk-instructions -->/d' "$COPILOT_CLI_FILE")"
  fi

  printf "${COLOR_BLUE}Running${COLOR_OFF} 'rtk init -g --copilot'...\n"
  rtk init -g --copilot

  local rtk_block
  rtk_block="$(cat "$COPILOT_CLI_FILE")"

  if [ -n "$(echo "$custom_content" | tr -d '[:space:]')" ]; then
    printf "${COLOR_BLUE}Merging${COLOR_OFF} your custom content with the freshly generated RTK block...\n"
    {
      printf '%s\n\n' "$custom_content"
      printf '%s\n' "$rtk_block"
    } > "$COPILOT_CLI_FILE"
    printf "${COLOR_GREEN}Done${COLOR_OFF}: '${COPILOT_CLI_FILE}' now has your custom instructions plus the current RTK block.\n"
  else
    printf "${COLOR_GREEN}Done${COLOR_OFF}: no existing custom content found, '${COPILOT_CLI_FILE}' now has the current RTK block only.\n"
  fi
}

setup_claude() {
  local instructions="$1"
  printf "${COLOR_BLUE}Setting up Claude Code${COLOR_OFF} (%s)...\n" "$([ "$GLOBAL" = "1" ] && echo personal || echo repo)"

  if [ "$GLOBAL" = "1" ]; then
    mkdir -p "${HOME}/.claude"
    fetch "ai/common/instructions/general.instructions.md" "${HOME}/.claude/general-instructions.md" --strip --backup
    touch "${HOME}/.claude/CLAUDE.md"
    grep -qxF '@general-instructions.md' "${HOME}/.claude/CLAUDE.md" || \
      echo '@general-instructions.md' >> "${HOME}/.claude/CLAUDE.md"
  else
    # Every selected instruction goes into one CLAUDE.md; applyTo scoping is Copilot-only, so
    # the frontmatter is dropped. The file is only replaced once all the downloads succeeded.
    local tmp name
    tmp="$(mktemp "CLAUDE.md.XXXXXX")"
    for name in $instructions; do
      if ! { curl -fsSL "${RAW_BASE}/ai/common/instructions/${name}.instructions.md" | strip_frontmatter >> "$tmp"; printf '\n' >> "$tmp"; }; then
        rm -f "$tmp"
        printf "${COLOR_RED}Error${COLOR_OFF}: could not download the '%s' instructions.\n" "$name" >&2
        return 1
      fi
    done
    place "$tmp" "CLAUDE.md" 1
  fi

  local skills_dir="${HOME}/.claude/skills"
  [ "$GLOBAL" = "1" ] || skills_dir=".claude/skills"
  for skill in code-review repository-audit commit-message pull-request; do
    mkdir -p "${skills_dir}/${skill}"
    fetch "ai/common/skills/${skill}/SKILL.md" "${skills_dir}/${skill}/SKILL.md"
  done
  mkdir -p "${skills_dir}/systematic-debugging"
  fetch "ai/claude/skills/systematic-debugging/SKILL.md" "${skills_dir}/systematic-debugging/SKILL.md"

  if [ "$WITH_AGENTS" = "1" ]; then
    local agents_dir="${HOME}/.claude/agents"
    [ "$GLOBAL" = "1" ] || agents_dir=".claude/agents"
    mkdir -p "$agents_dir"
    for agent in code-reviewer security-auditor refactorer test-writer doc-writer migration-assistant iac-reviewer; do
      fetch "ai/claude/agents/${agent}.md" "${agents_dir}/${agent}.md"
    done
  fi

  printf "${COLOR_GREEN}Claude Code setup done.${COLOR_OFF}\n"
}

setup_claude_plugins() {
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

# Put the general instructions into Copilot CLI's personal file as a marked block. A previous
# block is replaced; everything outside it (rtk's block, your own content) is preserved.
write_copilot_cli_block() {
  local begin='<!-- general-instructions -->' end='<!-- /general-instructions -->' body custom tmp
  body="$(curl -fsSL "${RAW_BASE}/ai/common/instructions/general.instructions.md" | strip_frontmatter)" || {
    printf "${COLOR_RED}Error${COLOR_OFF}: could not download the general instructions.\n" >&2
    return 1
  }

  custom=""
  if [ -f "$COPILOT_CLI_FILE" ]; then
    custom="$(sed "\#${begin}#,\#${end}#d" "$COPILOT_CLI_FILE")"
    if [ -z "$(grep -F "$begin" "$COPILOT_CLI_FILE")" ] && grep -q '^# General Development Instructions' "$COPILOT_CLI_FILE"; then
      printf "${COLOR_RED}Warning${COLOR_OFF}: '%s' already holds an unmarked copy of the general instructions from an older run; remove it by hand so it is not loaded twice.\n" "$COPILOT_CLI_FILE"
    fi
  fi

  tmp="$(mktemp "${COPILOT_CLI_FILE}.XXXXXX")"
  {
    if [ -n "$(printf '%s' "$custom" | tr -d '[:space:]')" ]; then
      printf '%s\n\n' "$custom"
    fi
    printf '%s\n%s\n%s\n' "$begin" "$body" "$end"
  } > "$tmp"
  place "$tmp" "$COPILOT_CLI_FILE" 1
}

setup_copilot() {
  local instructions="$1"
  printf "${COLOR_BLUE}Setting up GitHub Copilot${COLOR_OFF} (%s)...\n" "$([ "$GLOBAL" = "1" ] && echo personal || echo repo)"

  local instructions_dir=".github/instructions"
  [ "$GLOBAL" = "1" ] && instructions_dir="${HOME}/.copilot/instructions"
  mkdir -p "$instructions_dir"
  for name in $instructions; do
    fetch "ai/common/instructions/${name}.instructions.md" "${instructions_dir}/${name}.instructions.md" --backup
  done

  local skills_dir=".github/skills"
  [ "$GLOBAL" = "1" ] && skills_dir="${HOME}/.copilot/skills"
  for skill in code-review repository-audit commit-message pull-request; do
    mkdir -p "${skills_dir}/${skill}"
    fetch "ai/common/skills/${skill}/SKILL.md" "${skills_dir}/${skill}/SKILL.md"
  done

  if [ "$WITH_AGENTS" = "1" ]; then
    local agents_dir=".github/agents"
    [ "$GLOBAL" = "1" ] && agents_dir="${HOME}/.copilot/agents"
    mkdir -p "$agents_dir"
    for agent in code-reviewer security-auditor refactorer test-writer doc-writer migration-assistant iac-reviewer; do
      fetch "ai/copilot/agents/${agent}.md" "${agents_dir}/${agent}.md"
    done
  fi

  if [ "$GLOBAL" = "1" ]; then
    printf "${COLOR_BLUE}Note${COLOR_OFF}: personal instructions/skills/agents need opt-in via VS Code settings.json — see docs/02-ai.md#configure-via-settingsjson.\n"

    if [ "$WITH_CLI" = "1" ]; then
      mkdir -p "${HOME}/.copilot"
      write_copilot_cli_block
      printf "${COLOR_BLUE}Note${COLOR_OFF}: added the general instructions to Copilot CLI's personal file (%s) as a marked block; rtk's block and your own content are untouched.\n" "$COPILOT_CLI_FILE"
    fi
  fi
  printf "${COLOR_GREEN}GitHub Copilot setup done.${COLOR_OFF}\n"
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

  if [ "$RTK_MERGE" = "1" ]; then
    merge_rtk_copilot
    exit 0
  fi

  case "$TOOL" in
    claude|copilot|both) ;;
    *)
      printf "${COLOR_RED}Error${COLOR_OFF}: invalid -t value '%s' (expected 'claude', 'copilot', or 'both').\n" "$TOOL"
      exit 1;;
  esac

  if [ "$WITH_CLI" = "1" ] && [ "$GLOBAL" = "0" ]; then
    printf "${COLOR_RED}Warning${COLOR_OFF}: -c only applies with -g (personal setup) — ignoring it for this repo-level run.\n"
    WITH_CLI=0
  fi

  if [ "$WITH_PLUGINS" = "1" ] && [ "$TOOL" = "copilot" ]; then
    printf "${COLOR_RED}Warning${COLOR_OFF}: -P is Claude Code-only — ignoring it for this '-t copilot' run.\n"
    WITH_PLUGINS=0
  fi

  INSTRUCTIONS="$(resolve_instructions)"

  if [ "$TOOL" = "claude" ] || [ "$TOOL" = "both" ]; then
    setup_claude "$INSTRUCTIONS"
    if [ "$WITH_PLUGINS" = "1" ]; then
      setup_claude_plugins
    fi
  fi
  if [ "$TOOL" = "copilot" ] || [ "$TOOL" = "both" ]; then
    setup_copilot "$INSTRUCTIONS"
  fi
}

main "$@"
