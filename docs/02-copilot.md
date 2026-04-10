# AI Coding Instructions

Reusable coding instructions, agent skills, custom agents, and prompt templates for AI coding agents.
All canonical content lives in `copilot/`.

## Customization Overview

GitHub Copilot (VS Code, CLI, cloud agent) now supports multiple customization layers:

| Feature                 | Purpose                                      | Repo location                                                               | When loaded                       |
| ----------------------- | -------------------------------------------- | --------------------------------------------------------------------------- | --------------------------------- |
| **Custom instructions** | Always-on standards & conventions            | `.github/copilot-instructions.md`, `.github/instructions/*.instructions.md` | Every interaction (auto)          |
| **Agent Skills**        | Task-specific workflows with bundled assets  | `.github/skills/<name>/SKILL.md`                                            | On demand (auto or `/skill-name`) |
| **Custom Agents**       | Specialist personas with scoped tools        | `.github/agents/<name>.md`                                                  | On demand (agent picker)          |
| **Prompt files**        | Reusable one-shot templates with variables   | `.github/prompts/*.prompt.md`                                               | On demand (manual)                |
| **Hooks**               | Deterministic automation at lifecycle events | `.github/hooks/*.json`                                                      | Automatic at configured events    |
| **MCP servers**         | External tool/API connections                | `mcp.json`                                                                  | Automatic                         |

> **Rule of thumb**: Use *instructions* for guidance that applies broadly. Use *skills* for detailed workflows Copilot should only load when relevant. Use *agents* for specialist personas with restricted toolsets.

### Discovery order by tool

Each tool has its own discovery model. **Repository-level** settings take precedence over personal ones.

| Tool                   | Repo instructions                                                                    | Skills                                                                              | Personal                                                                |
| ---------------------- | ------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| **VS Code Chat**       | `.github/copilot-instructions.md`, `.github/instructions/`, `AGENTS.md`, `CLAUDE.md` | `.github/skills/`, `.claude/skills/`, `~/.copilot/skills/`\*, `~/.claude/skills/`\* | `~/.copilot/instructions/`†, `~/.claude/rules/`†, `~/.claude/CLAUDE.md` |
| **Copilot CLI**        | `.github/copilot-instructions.md`, `.github/skills/`, `AGENTS.md`                    | `.github/skills/`, `~/.copilot/skills/`                                             | `~/.copilot/copilot-instructions.md`                                    |
| **GitHub cloud agent** | `.github/copilot-instructions.md`, `.github/instructions/`, `AGENTS.md`              | —                                                                                   | —                                                                       |
| **Claude Code**        | `CLAUDE.md`, `.claude/skills/`                                                       | `.claude/skills/`                                                                   | `~/.claude/CLAUDE.md`, `~/.claude/skills/`                              |
| **OpenAI Codex**       | `AGENTS.md`, `CODEX.md`                                                              | —                                                                                   | —                                                                       |

\* Enabled by default in VS Code via `chat.agentSkillsLocations`.
† Opt-in — add to `chat.instructionsFilesLocations` to enable.

Alias files (`AGENTS.md`, `CLAUDE.md`, `Copilot.md`, `GEMINI.md`, `CODEX.md`) provide cross-tool compatibility — most modern coding agents recognize them.

## Available Instructions

| Name                                                                        | Description                          | Instruction Name | Type         |
| --------------------------------------------------------------------------- | ------------------------------------ | ---------------- | ------------ |
| [Consolidated](../copilot/copilot-instructions.md)                          | All best practices in one file       | —                | General      |
| [Code Review](../copilot/instructions/code-review.instructions.md)          | Code review guidelines (lightweight) | `code-review`    | Review       |
| [Commit Message](../copilot/instructions/commit-message.instructions.md)    | Conventional Commits format          | `commit-message` | Git          |
| [Pull Request](../copilot/instructions/pull-request.md)                     | PR description best practices        | `pull-request`   | Git          |
| [General Development](../copilot/instructions/general.instructions.md)      | Universal development practices      | `general`        | General      |
| [JavaScript/TypeScript](../copilot/instructions/javascript.instructions.md) | Scoped to JS/TS files (incl. Bun)    | `javascript`     | Language     |
| [Go](../copilot/instructions/go.instructions.md)                            | Scoped to Go files                   | `go`             | Language     |
| [Bash/Shell](../copilot/instructions/shell.instructions.md)                 | Scoped to shell scripts              | `shell`          | Language     |
| [Python](../copilot/instructions/python.instructions.md)                    | Scoped to Python files (FastAPI)     | `python`         | Language     |
| [TypeScript Monorepo](../copilot/instructions/ts-monorepo.instructions.md)  | Complete TS monorepo setup           | `ts-monorepo`    | Architecture |
| [Docker](../copilot/instructions/docker.instructions.md)                    | Scoped to Dockerfiles                | `docker`         | Platform     |
| [Kubernetes/Helm](../copilot/instructions/kubernetes.instructions.md)       | Scoped to K8s YAML files             | `kubernetes`     | Platform     |
| [GitHub Actions](../copilot/instructions/github-actions.instructions.md)    | Scoped to workflow files             | `github-actions` | CI/CD        |
| [Terraform/IaC](../copilot/instructions/terraform.instructions.md)          | Scoped to Terraform files            | `terraform`      | Platform     |

## Agent Skills

Skills are folders of instructions loaded on demand when Copilot detects they are relevant to a task. They avoid bloating the context window with instructions that aren't needed.

| Name                                                            | Description                                                          | Skill Name         |
| --------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------ |
| [Code Review](../copilot/skills/code-review/SKILL.md)           | Full review methodology with language checks & decision framework    | `code-review`      |
| [Repository Audit](../copilot/skills/repository-audit/SKILL.md) | Comprehensive repo analysis (quality, security, performance, DevOps) | `repository-audit` |
| [Commit Message](../copilot/skills/commit-message/SKILL.md)     | Conventional Commits generation                                      | `commit-message`   |
| [Pull Request](../copilot/skills/pull-request/SKILL.md)         | PR description generation                                            | `pull-request`     |

### Setup skills (repository)

```sh
mkdir -p .github/skills
for skill in code-review repository-audit commit-message pull-request; do
  mkdir -p ".github/skills/${skill}"
  curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/skills/${skill}/SKILL.md" \
    -o ".github/skills/${skill}/SKILL.md"
done
```

### Setup skills (personal — shared across all repos)

Personal skills in `~/.copilot/skills/` and `~/.claude/skills/` are **read by VS Code by default** (no settings change needed) and by Copilot CLI:

```sh
for skill in code-review repository-audit commit-message pull-request; do
  mkdir -p "${HOME}/.copilot/skills/${skill}"
  curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/skills/${skill}/SKILL.md" \
    -o "${HOME}/.copilot/skills/${skill}/SKILL.md"
done
```

### Using skills

- **Automatic**: Copilot detects when a skill is relevant and loads it (based on `description` in frontmatter)
- **Explicit**: Include the skill name with a `/` prefix in your prompt: `/code-review analyze the auth module`
- **CLI**: Use `/skills list` to see available skills, `/skills info` for details

## Custom Agents

Agents define specialist personas with their own instructions and restricted tool access.

| Name                                                      | Description                             | Tools            |
| --------------------------------------------------------- | --------------------------------------- | ---------------- |
| [Code Reviewer](../copilot/agents/code-reviewer.md)       | Read-only code review specialist        | `read`, `search` |
| [Security Auditor](../copilot/agents/security-auditor.md) | Security-focused vulnerability analysis | `read`, `search` |

### Setup agents (repository)

```sh
mkdir -p .github/agents
for agent in code-reviewer security-auditor; do
  curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/agents/${agent}.md" \
    -o ".github/agents/${agent}.md"
done
```

### Setup agents (personal — VS Code only)

Personal agents are supported in VS Code via `chat.agentFilesLocations`. Copilot CLI does not support a personal agents directory.

```sh
mkdir -p ~/.copilot/agents
for agent in code-reviewer security-auditor; do
  curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/agents/${agent}.md" \
    -o "${HOME}/.copilot/agents/${agent}.md"
done
```

Enable in user `settings.json`:

```json
{
  "chat.agentFilesLocations": {
    ".github/agents": true,
    "~/.copilot/agents": true
  }
}
```

### Using agents

- **VS Code**: Select the agent from the agent dropdown in the Chat panel
- **Copilot CLI**: Copilot auto-delegates to an agent when it detects a matching task (unless `disable-model-invocation: true`)
- **Cloud agent**: Agents are available when assigned to a task on GitHub

### Agent configuration

Agent files support these YAML frontmatter properties:

```yaml
---
description: What the agent does (required)
tools: ["read", "search"]     # Restrict available tools (omit for all)
model: claude-sonnet-4-5       # Override model (optional)
disable-model-invocation: false # If true, must be manually selected
---
```

Tool aliases: `read`, `edit`, `search`, `execute` (shell), `web`, `agent`, `todo`.

## Prompts

| Name                                              | Description                                        | Prompt Name |
| ------------------------------------------------- | -------------------------------------------------- | ----------- |
| [Repository Review](../copilot/prompts/review.md) | Full repo analysis: quality, security, performance | `review`    |

---

## GitHub Copilot (VS Code)

### How it works

GitHub Copilot in VS Code reads instructions from several locations, including your home directory for skills:

| File/Folder                              | Purpose                                                                   |
| ---------------------------------------- | ------------------------------------------------------------------------- |
| `.github/copilot-instructions.md`        | Global workspace prompt — always active                                   |
| `AGENTS.md`, `CLAUDE.md`                 | Cross-tool alias — always active                                          |
| `.github/instructions/*.instructions.md` | Scoped — activated by `applyTo` glob                                      |
| `.github/skills/<name>/SKILL.md`         | Agent skills (repo) — on demand                                           |
| `~/.copilot/skills/<name>/SKILL.md`      | Agent skills (personal) — on demand, **enabled by default**               |
| `~/.claude/skills/<name>/SKILL.md`       | Agent skills (personal, Claude alias) — on demand, **enabled by default** |
| `.github/agents/<name>.md`               | Custom agents — selectable from the agent picker                          |
| `.github/prompts/*.prompt.md`            | Prompt files — reusable templates                                         |

### Personal instructions (user profile)

Create `*.instructions.md` files in `~/.copilot/instructions/` to apply personal conventions to all your workspaces. They are **not enabled by default** — opt in via `chat.instructionsFilesLocations` in your user `settings.json`:

```sh
mkdir -p ~/.copilot/instructions
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/general.instructions.md" \
  -o "${HOME}/.copilot/instructions/general.instructions.md"
```

Then enable in user `settings.json` (`Cmd+Shift+P` → "Open User Settings (JSON)"):

```json
{
  "chat.instructionsFilesLocations": {
    ".github/instructions": true,
    "~/.copilot/instructions": true
  }
}
```

### Setup

**Option 1 — Single consolidated file** (quickest)

```sh
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/copilot-instructions.md" \
  -o ".github/copilot-instructions.md"
```

**Option 2 — Scoped instructions** (recommended for multi-tech repos)

```sh
mkdir -p .github/instructions
INSTRUCTIONS="javascript docker kubernetes github-actions"
for name in $INSTRUCTIONS; do
  curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/${name}.instructions.md" \
    -o ".github/instructions/${name}.instructions.md"
done
```

**Option 3 — Full setup** (instructions + skills + agents)

```sh
# Instructions
mkdir -p .github/instructions
for name in general javascript docker kubernetes github-actions; do
  curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/${name}.instructions.md" \
    -o ".github/instructions/${name}.instructions.md"
done

# Skills
for skill in code-review repository-audit commit-message pull-request; do
  mkdir -p ".github/skills/${skill}"
  curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/skills/${skill}/SKILL.md" \
    -o ".github/skills/${skill}/SKILL.md"
done

# Agents
mkdir -p .github/agents
for agent in code-reviewer security-auditor; do
  curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/agents/${agent}.md" \
    -o ".github/agents/${agent}.md"
done
```

### Configure via `settings.json`

All customization features can be enabled and relocated via settings. The workspace `.vscode/settings.json` applies to the project; your user `settings.json` applies globally.

```jsonc
{
  // ── Instructions ─────────────────────────────────────────────────────────
  // Where to look for *.instructions.md files (supports ~ expansion)
  "chat.instructionsFilesLocations": {
    ".github/instructions": true,     // workspace (default on)
    ".claude/rules": true,            // workspace, Claude format
    "~/.copilot/instructions": true,  // personal — opt in to enable
    "~/.claude/rules": true           // personal, Claude format — opt in
  },
  "chat.includeApplyingInstructions": true,    // auto-include files with matching applyTo
  "chat.useAgentsMdFile": true,                // AGENTS.md always-on
  "chat.useClaudeMdFile": true,                // CLAUDE.md always-on

  // ── Skills ───────────────────────────────────────────────────────────────
  // All four locations enabled by default
  "chat.useAgentSkills": true,
  "chat.agentSkillsLocations": {
    ".github/skills": true,       // workspace
    ".claude/skills": true,       // workspace, Claude alias
    "~/.copilot/skills": true,    // personal (default on)
    "~/.claude/skills": true      // personal, Claude alias (default on)
  },

  // ── Agents ───────────────────────────────────────────────────────────────
  // Add personal agents location (not enabled by default)
  "chat.agentFilesLocations": {
    ".github/agents": true,       // workspace (default on)
    "~/.copilot/agents": true     // personal — add to enable
  },

  // ── Prompts ──────────────────────────────────────────────────────────────
  "chat.promptFilesLocations": {
    ".github/prompts": true       // workspace (default on)
  },

  // ── Per-feature instructions (commit, PR, review) ────────────────────────
  // Note: codeGeneration.instructions is deprecated since VS Code 1.102
  //       use *.instructions.md files with applyTo: "**" instead
  "github.copilot.chat.commitMessageGeneration.instructions": [
    { "file": ".github/instructions/commit-message.instructions.md" }
  ],
  "github.copilot.chat.pullRequestDescriptionGeneration.instructions": [
    { "file": ".github/instructions/pull-request.md" }
  ],
  "github.copilot.chat.reviewSelection.instructions": [
    { "file": ".github/instructions/code-review.instructions.md" }
  ],

  // ── Monorepo ─────────────────────────────────────────────────────────────
  // Discover instructions/skills/agents from parent folder when opening a subfolder
  "chat.useCustomizationsInParentRepositories": false
}
```

### Git workflow instructions (commit + PR)

```sh
mkdir -p .github/instructions
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/commit-message.instructions.md" \
  -o ".github/instructions/commit-message.instructions.md"
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/pull-request.md" \
  -o ".github/instructions/pull-request.md"
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/code-review.instructions.md" \
  -o ".github/instructions/code-review.instructions.md"
```

### Prompts

```sh
mkdir -p .github/prompts
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/prompts/review.md" \
  -o ".github/prompts/review.md"
```

---

## Copilot CLI

Copilot CLI reads from both the repository and your home directory. Personal config in `~/.copilot/` is loaded every session across all repos.

| File                                               | Scope                              |
| -------------------------------------------------- | ---------------------------------- |
| `~/.copilot/copilot-instructions.md`               | Personal (all sessions, all repos) |
| `~/.copilot/skills/<name>/SKILL.md`                | Personal skills (all repos)        |
| `.github/copilot-instructions.md`                  | Repository                         |
| `.github/skills/<name>/SKILL.md`                   | Repository skills                  |
| `AGENTS.md`, `Copilot.md`, `GEMINI.md`, `CODEX.md` | Repository (cross-tool aliases)    |

### Personal setup (applies to all repos)

```sh
# Personal instructions — always loaded in every Copilot CLI session
mkdir -p ~/.copilot
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/copilot-instructions.md" \
  -o "${HOME}/.copilot/copilot-instructions.md"

# Personal skills — available everywhere
for skill in code-review repository-audit commit-message pull-request; do
  mkdir -p "${HOME}/.copilot/skills/${skill}"
  curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/skills/${skill}/SKILL.md" \
    -o "${HOME}/.copilot/skills/${skill}/SKILL.md"
done
```

### Key CLI commands

| Command            | Purpose                                     |
| ------------------ | ------------------------------------------- |
| `/skills list`     | List available skills                       |
| `/skills info`     | Detail about a skill                        |
| `/skills reload`   | Reload after adding skills mid-session      |
| `/plan`            | Create an implementation plan before coding |
| `/review`          | Review current changes                      |
| `/delegate`        | Offload work to cloud agent                 |
| `/model`           | Switch model mid-session                    |
| `/context`         | Show context window usage                   |
| `/fleet`           | Break task into parallel subtasks           |
| `/clear` or `/new` | Reset context between unrelated tasks       |

### Allowed tools

Pre-configure tool permissions via CLI flags:

```sh
copilot --allow-tool='shell(git:*)' --deny-tool='shell(git push)'
```

Common patterns: `shell(git:*)`, `shell(npm run:*)`, `shell(bun:*)`, `write`.

---

## Claude Code

Claude Code reads `CLAUDE.md` at the repository root. Point it at the consolidated instructions:

```sh
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/copilot-instructions.md" \
  -o "CLAUDE.md"
```

Claude Code also reads skills from `.claude/skills/`:

```sh
for skill in code-review repository-audit commit-message pull-request; do
  mkdir -p ".claude/skills/${skill}"
  curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/skills/${skill}/SKILL.md" \
    -o ".claude/skills/${skill}/SKILL.md"
done
```

---

## AGENTS.md (OpenAI Codex / GitHub Copilot coding agent)

`AGENTS.md` at the repository root is read by OpenAI Codex and any agent following the AGENTS.md convention:

```sh
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/copilot-instructions.md" \
  -o "AGENTS.md"
```

---

## Recommended setup by project type

**JavaScript / TypeScript**

```sh
mkdir -p .github/instructions
for name in javascript docker github-actions; do
  curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/${name}.instructions.md" \
    -o ".github/instructions/${name}.instructions.md"
done
```

**Python (FastAPI)**

```sh
mkdir -p .github/instructions
for name in python docker github-actions; do
  curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/${name}.instructions.md" \
    -o ".github/instructions/${name}.instructions.md"
done
```

**Kubernetes / DevOps**

```sh
mkdir -p .github/instructions
for name in kubernetes docker github-actions terraform shell; do
  curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/${name}.instructions.md" \
    -o ".github/instructions/${name}.instructions.md"
done
```

**Go**

```sh
mkdir -p .github/instructions
for name in go docker github-actions; do
  curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/${name}.instructions.md" \
    -o ".github/instructions/${name}.instructions.md"
done
```

---

## Troubleshooting

### Instructions not applied (GitHub Copilot)

- File must be in `.github/` (or `.github/instructions/` for scoped files)
- Scoped files must end in `.instructions.md`
- Reload VS Code after adding new files or changing settings
- Check `applyTo` frontmatter — patterns are glob-style and case-sensitive:

```yaml
---
applyTo: "**/*.{js,ts}"
---
```

### Skills not loading

- Skill files must be named exactly `SKILL.md` (case-sensitive)
- Each skill needs its own subdirectory under `.github/skills/`
- YAML frontmatter must include `name` and `description`
- Use `/skills list` in Copilot CLI to verify discovery
- Use `/skills reload` after adding skills mid-session

### Instruction file too large

Split the content across multiple scoped files. Each one is only loaded when its `applyTo` pattern matches the file being edited. For task-specific workflows, convert to skills instead — they're only loaded when relevant.
