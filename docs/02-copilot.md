# AI Coding Instructions

Reusable coding instructions and prompt templates for AI coding agents.
All canonical content lives in `copilot/instructions/`.

## Available instructions

| Name                                                                        | Description                       | Instruction Name | Type         |
| --------------------------------------------------------------------------- | --------------------------------- | ---------------- | ------------ |
| [Consolidated](../copilot/copilot-instructions.md)                          | All best practices in one file    | —                | General      |
| [Code Review](../copilot/instructions/code-review.instructions.md)          | Expert code review guidelines     | `code-review`    | Review       |
| [Commit Message](../copilot/instructions/commit-message.instructions.md)    | Conventional Commits format       | `commit-message` | Git          |
| [Pull Request](../copilot/instructions/pull-request.md)                     | PR description best practices     | `pull-request`   | Git          |
| [General Development](../copilot/instructions/general.instructions.md)      | Universal development practices   | `general`        | General      |
| [JavaScript/TypeScript](../copilot/instructions/javascript.instructions.md) | Scoped to JS/TS files (incl. Bun) | `javascript`     | Language     |
| [Go](../copilot/instructions/go.instructions.md)                            | Scoped to Go files                | `go`             | Language     |
| [Bash/Shell](../copilot/instructions/shell.instructions.md)                 | Scoped to shell scripts           | `shell`          | Language     |
| [Python](../copilot/instructions/python.instructions.md)                    | Scoped to Python files (FastAPI)  | `python`         | Language     |
| [TypeScript Monorepo](../copilot/instructions/ts-monorepo.instructions.md)  | Complete TS monorepo setup        | `ts-monorepo`    | Architecture |
| [Docker](../copilot/instructions/docker.instructions.md)                    | Scoped to Dockerfiles             | `docker`         | Platform     |
| [Kubernetes/Helm](../copilot/instructions/kubernetes.instructions.md)       | Scoped to K8s YAML files          | `kubernetes`     | Platform     |
| [GitHub Actions](../copilot/instructions/github-actions.instructions.md)    | Scoped to workflow files          | `github-actions` | CI/CD        |
| [Terraform/IaC](../copilot/instructions/terraform.instructions.md)          | Scoped to Terraform files         | `terraform`      | Platform     |

## Prompts

| Name                                              | Description                                        | Prompt Name |
| ------------------------------------------------- | -------------------------------------------------- | ----------- |
| [Repository Review](../copilot/prompts/review.md) | Full repo analysis: quality, security, performance | `review`    |

---

## GitHub Copilot (VS Code)

### How it works

GitHub Copilot in VS Code reads instructions from two locations:

| File                                     | Purpose                                                       |
| ---------------------------------------- | ------------------------------------------------------------- |
| `.github/copilot-instructions.md`        | Global workspace system prompt — always active                |
| `.github/instructions/*.instructions.md` | Scoped instructions — activated by `applyTo` glob frontmatter |

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

### Wire features via `settings.json`

Add to `.vscode/settings.json` to route each Copilot feature to the right instruction file:

```json
{
  "github.copilot.chat.codeGeneration.instructions": [
    { "file": ".github/instructions/general.instructions.md" }
  ],
  "github.copilot.chat.commitMessageGeneration.instructions": [
    { "file": ".github/instructions/commit-message.instructions.md" }
  ],
  "github.copilot.chat.pullRequestDescriptionGeneration.instructions": [
    { "file": ".github/instructions/pull-request.md" }
  ],
  "github.copilot.chat.reviewSelection.instructions": [
    { "file": ".github/instructions/code-review.instructions.md" }
  ]
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

## Claude Code

Claude Code reads `CLAUDE.md` at the repository root. Point it at the consolidated instructions:

```sh
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/copilot-instructions.md" \
  -o "CLAUDE.md"
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

### Instruction file too large

Split the content across multiple scoped files. Each one is only loaded when its `applyTo` pattern matches the file being edited.
