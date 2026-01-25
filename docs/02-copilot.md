# Copilot

## Instructions

### Available instructions

| Name                                                                        | Description                     | Instruction Name | Type         |
| --------------------------------------------------------------------------- | ------------------------------- | ---------------- | ------------ |
| [Consolidated Instructions](../copilot/copilot-instructions.md)             | All best practices in one file  | -                | General      |
| [Code Review](../copilot/instructions/code-review.instructions.md)          | Expert code review guidelines   | `code-review`    | Review       |
| [Commit Message](../copilot/instructions/commit-message.md)                 | Conventional Commits format     | `commit-message` | Git          |
| [Pull Request](../copilot/instructions/pull-request.md)                     | PR description best practices   | `pull-request`   | Git          |
| [General Development](../copilot/instructions/general.instructions.md)      | Universal development practices | `general`        | General      |
| [JavaScript/TypeScript](../copilot/instructions/javascript.instructions.md) | Scoped to JS/TS files           | `javascript`     | Language     |
| [Go](../copilot/instructions/go.instructions.md)                            | Scoped to Go files              | `go`             | Language     |
| [Bash/Shell](../copilot/instructions/shell.instructions.md)                 | Scoped to shell scripts         | `shell`          | Language     |
| [TypeScript Monorepo](../copilot/instructions/ts-monorepo.instructions.md)  | Complete TS monorepo setup      | `ts-monorepo`    | Architecture |
| [Docker](../copilot/instructions/docker.instructions.md)                    | Scoped to Dockerfiles           | `docker`         | Platform     |
| [Kubernetes/Helm](../copilot/instructions/kubernetes.instructions.md)       | Scoped to K8s YAML files        | `kubernetes`     | Platform     |
| [GitHub Actions](../copilot/instructions/github-actions.instructions.md)    | Scoped to workflow files        | `github-actions` | CI/CD        |

#### Usage

This collection follows GitHub's official Copilot instructions format with multiple approaches:

**Option 1: Clone All Instructions** (Recommended for personal machine setup)
```sh
# Clone instructions to ~/.config/copilot
curl -fsSL https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/clone-subdir.sh | bash -s -- \
  -u "https://github.com/this-is-tobi/tools" \
  -b "main" \
  -s "copilot/instructions" \
  -o "$HOME/.config/copilot" \
  -d
```

This will clone all instruction files to `~/.config/copilot/instructions/`. Then configure VS Code with absolute paths:
```json
{
  "github.copilot.chat.codeGeneration.instructions": [
    { "file": "/Users/<username>/.config/copilot/instructions/code-review.md" }
  ],
  "github.copilot.chat.commitMessageGeneration.instructions": [
    { "file": "/Users/<username>/.config/copilot/instructions/commit-message.md" }
  ],
  "github.copilot.chat.pullRequestDescriptionGeneration.instructions": [
    { "file": "/Users/<username>/.config/copilot/instructions/pull-request.md" }
  ]
}
```

**Option 2: Single File** (For project-specific setup)
```sh
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/copilot-instructions.md" \
  -o ".github/copilot-instructions.md"
```

**Option 3: Git Workflow Instructions** (For commit messages and PR descriptions)
```sh
# For commit message generation
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/commit-message.md" \
  -o ".github/instructions/commit-message.md"

# For PR description generation
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/pull-request.md" \
  -o ".github/instructions/pull-request.md"

# For code review
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/code-review.md" \
  -o ".github/instructions/code-review.md"
```

Then configure VS Code settings with relative paths:
```json
{
  "github.copilot.chat.codeGeneration.instructions": [
    { "file": ".github/instructions/code-review.md" }
  ],
  "github.copilot.chat.commitMessageGeneration.instructions": [
    { "file": ".github/instructions/commit-message.md" }
  ],
  "github.copilot.chat.pullRequestDescriptionGeneration.instructions": [
    { "file": ".github/instructions/pull-request.md" }
  ]
}
```

**Option 4: Scoped Instructions** (For complex multi-technology projects)
```sh
# Create instructions directory
mkdir -p .github/instructions

# Copy specific instructions
INSTRUCTION_NAME="javascript"  # or "go", "docker", "kubernetes", etc.
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/$INSTRUCTION_NAME.instructions.md" \
  -o ".github/instructions/$INSTRUCTION_NAME.instructions.md"
```

#### Features

- **GitHub Official Format**: Uses `.github/copilot-instructions.md` and `.github/instructions/*.instructions.md`
- **Specialized Instructions**: Separate files for code review, commits, and PR descriptions
- **Scoped Instructions**: Technology-specific instructions with `applyTo` frontmatter
- **File Targeting**: Instructions only apply to relevant file types
- **Modular Design**: Mix and match technologies as needed
- **VS Code Integration**: Configure specific instructions for different Copilot features
- **Template Checking**: Automatically detects and uses existing repository templates

## Best Practices

### Recommended Setup by Project Type

**JavaScript/TypeScript Project:**
```sh
mkdir -p .github/instructions
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/javascript.instructions.md" \
  -o ".github/instructions/javascript.instructions.md"
```

**Kubernetes/DevOps Project:**
```sh
mkdir -p .github/instructions
for file in kubernetes docker github-actions; do
  curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/$file.instructions.md" \
    -o ".github/instructions/$file.instructions.md"
done
```

**Go Project:**
```sh
mkdir -p .github/instructions
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/go.instructions.md" \
  -o ".github/instructions/go.instructions.md"
```

## Troubleshooting

### Instructions Not Working

**Verify file location:**
- Instructions must be in `.github/` directory
- Use naming convention: `*.instructions.md` for scoped instructions

**Check VS Code settings:**
```json
{
  "github.copilot.chat.codeGeneration.instructions": [
    { "file": ".github/instructions/code-review.md" }
  ]
}
```

**Reload VS Code** after adding new instructions or changing settings.

### Scoped Instructions Not Applying

Check frontmatter syntax:
```yaml
---
applyTo:
  - "**/*.js"
  - "**/*.ts"
---
```

Patterns are glob-style and case-sensitive.

### Prompts

| Name                                              | Description                                                        | Prompt Name |
| ------------------------------------------------- | ------------------------------------------------------------------ | ----------- |
| [Repository Review](../copilot/prompts/review.md) | Review a repository for code quality, security, and best practices | `review`    |

#### Usage

```sh
# Create instructions directory
mkdir -p .github/prompts

# Copy specific prompt
PROMPT_NAME="review" # or any other prompt name
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/prompts/$PROMPT_NAME.md" \
  -o ".github/prompts/$PROMPT_NAME.md"
```

#### Features

- **GitHub Official Format**: Uses `.github/prompts/<prompt_name>.md`
- **Comprehensive Review**: In-depth analysis of code quality, security, performance, and more
- **Detailed Checklist**: Covers 19 critical areas of software development
- **Actionable Feedback**: Provides explanations and solutions for identified issues
- **Customizable**: Easily adapt the prompt to fit specific project needs
