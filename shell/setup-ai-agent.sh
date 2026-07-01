#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'

# Defaults
RAW_BASE="https://raw.githubusercontent.com/this-is-tobi/tools/main"
TOOL="both"
PRESET="general"
CUSTOM_INSTRUCTIONS=""
WITH_AGENTS=0
GLOBAL=0
WITH_CLI=0
RTK_MERGE=0
COPILOT_CLI_FILE="${HOME}/.copilot/copilot-instructions.md"

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
  -g    Personal/global setup (~/.claude, ~/.copilot) instead of repo-level.
  -c    Also populate Copilot CLI's personal file (~/.copilot/copilot-instructions.md), always just
        'general' regardless of -p/-i (matches how Copilot CLI's personal setup works — one always-loaded
        file, no per-repo scoping). Only applies with -g and -t copilot/both; ignored otherwise.
  -r    Run 'rtk init -g --copilot' safely instead of setting anything up: backs up whatever is already in
        '${COPILOT_CLI_FILE}', lets rtk regenerate its block, then merges the two back together (rtk's own
        installer overwrites that file entirely otherwise). Safe to re-run — never duplicates the block.
        Standalone action, ignores every other flag except -h.
  -h    Print script help.

Examples:
  ./setup-ai-agent.sh -t claude
  ./setup-ai-agent.sh -t copilot -p javascript -a
  ./setup-ai-agent.sh -t both -g
  ./setup-ai-agent.sh -t copilot -g -c
  ./setup-ai-agent.sh -r
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
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
    curl -fsSL "${RAW_BASE}/ai/common/instructions/general.instructions.md" \
      -o "${HOME}/.claude/general-instructions.md"
    touch "${HOME}/.claude/CLAUDE.md"
    grep -qxF '@general-instructions.md' "${HOME}/.claude/CLAUDE.md" || \
      echo '@general-instructions.md' >> "${HOME}/.claude/CLAUDE.md"
  else
    local first=1
    for name in $instructions; do
      if [ "$first" = "1" ]; then
        curl -fsSL "${RAW_BASE}/ai/common/instructions/${name}.instructions.md" -o "CLAUDE.md"
        first=0
      else
        curl -fsSL "${RAW_BASE}/ai/common/instructions/${name}.instructions.md" >> "CLAUDE.md"
      fi
    done
  fi

  local skills_dir="${HOME}/.claude/skills"
  [ "$GLOBAL" = "1" ] || skills_dir=".claude/skills"
  for skill in code-review repository-audit commit-message pull-request; do
    mkdir -p "${skills_dir}/${skill}"
    curl -fsSL "${RAW_BASE}/ai/common/skills/${skill}/SKILL.md" -o "${skills_dir}/${skill}/SKILL.md"
  done

  if [ "$WITH_AGENTS" = "1" ]; then
    local agents_dir="${HOME}/.claude/agents"
    [ "$GLOBAL" = "1" ] || agents_dir=".claude/agents"
    mkdir -p "$agents_dir"
    for agent in code-reviewer security-auditor refactorer test-writer doc-writer migration-assistant iac-reviewer; do
      curl -fsSL "${RAW_BASE}/ai/claude/agents/${agent}.md" -o "${agents_dir}/${agent}.md"
    done
  fi

  printf "${COLOR_GREEN}Claude Code setup done.${COLOR_OFF}\n"
}

setup_copilot() {
  local instructions="$1"
  printf "${COLOR_BLUE}Setting up GitHub Copilot${COLOR_OFF} (%s)...\n" "$([ "$GLOBAL" = "1" ] && echo personal || echo repo)"

  local instructions_dir=".github/instructions"
  [ "$GLOBAL" = "1" ] && instructions_dir="${HOME}/.copilot/instructions"
  mkdir -p "$instructions_dir"
  for name in $instructions; do
    curl -fsSL "${RAW_BASE}/ai/common/instructions/${name}.instructions.md" \
      -o "${instructions_dir}/${name}.instructions.md"
  done

  local skills_dir=".github/skills"
  [ "$GLOBAL" = "1" ] && skills_dir="${HOME}/.copilot/skills"
  for skill in code-review repository-audit commit-message pull-request; do
    mkdir -p "${skills_dir}/${skill}"
    curl -fsSL "${RAW_BASE}/ai/common/skills/${skill}/SKILL.md" -o "${skills_dir}/${skill}/SKILL.md"
  done

  if [ "$WITH_AGENTS" = "1" ]; then
    local agents_dir=".github/agents"
    [ "$GLOBAL" = "1" ] && agents_dir="${HOME}/.copilot/agents"
    mkdir -p "$agents_dir"
    for agent in code-reviewer security-auditor refactorer test-writer doc-writer migration-assistant iac-reviewer; do
      curl -fsSL "${RAW_BASE}/ai/copilot/agents/${agent}.md" -o "${agents_dir}/${agent}.md"
    done
  fi

  if [ "$GLOBAL" = "1" ]; then
    printf "${COLOR_BLUE}Note${COLOR_OFF}: personal instructions/skills/agents need opt-in via VS Code settings.json — see docs/02-ai.md#configure-via-settingsjson.\n"

    if [ "$WITH_CLI" = "1" ]; then
      mkdir -p "${HOME}/.copilot"
      curl -fsSL "${RAW_BASE}/ai/common/instructions/general.instructions.md" \
        -o "$COPILOT_CLI_FILE"
      printf "${COLOR_BLUE}Note${COLOR_OFF}: populated Copilot CLI's personal file too (%s). If you later run 'rtk init -g --copilot', use this script's -r flag instead of running it raw, or it'll wipe this file.\n" "$COPILOT_CLI_FILE"
    fi
  fi
  printf "${COLOR_GREEN}GitHub Copilot setup done.${COLOR_OFF}\n"
}

# Parse options
while getopts t:p:i:acgrh flag
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
    c)
      WITH_CLI=1;;
    g)
      GLOBAL=1;;
    r)
      RTK_MERGE=1;;
    h | *)
      print_help
      exit 0;;
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

INSTRUCTIONS="$(resolve_instructions)"

if [ "$TOOL" = "claude" ] || [ "$TOOL" = "both" ]; then
  setup_claude "$INSTRUCTIONS"
fi
if [ "$TOOL" = "copilot" ] || [ "$TOOL" = "both" ]; then
  setup_copilot "$INSTRUCTIONS"
fi

exit 0
