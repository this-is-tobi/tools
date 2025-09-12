# Copilot

## Available instructions

| Name                                                                        | Description                        | Instructions Name |
| --------------------------------------------------------------------------- | ---------------------------------- | ----------------- |
| [Consolidated Instructions](../copilot/copilot-instructions.md)             | General best practices in one file | -                 |
| [JavaScript/TypeScript](../copilot/instructions/javascript.instructions.md) | Scoped to JS/TS files              | `javascript`      |
| [Go](../copilot/instructions/go.instructions.md)                            | Scoped to Go files                 | `go`              |
| [Kubernetes/Helm](../copilot/instructions/kubernetes.instructions.md)       | Scoped to K8s YAML files           | `kubernetes`      |
| [GitHub Actions](../copilot/instructions/github-actions.instructions.md)    | Scoped to workflow files           | `github-actions`  |
| [Docker](../copilot/instructions/docker.instructions.md)                    | Scoped to Dockerfiles              | `docker`          |
| [Bash/Shell](../copilot/instructions/shell.instructions.md)                 | Scoped to shell scripts            | `shell`           |
| [TypeScript Monorepo](../copilot/instructions/ts-monorepo.instructions.md)  | Scoped to TS monorepos             | `ts-monorepo`     |
| [General Development](../copilot/instructions/general.instructions.md)      | Universal practices                | `general`         |

## Usage

This collection follows GitHub's official Copilot instructions format with two approaches:

**Option 1: Single File** (Recommended for most projects)
```sh
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/copilot-instructions.md" \
  -o ".github/copilot-instructions.md"
```

**Option 2: Scoped Instructions** (For complex multi-technology projects)
```sh
# Create instructions directory
mkdir -p .github/instructions

# Copy specific technology instructions
INSTRUCTION_NAME="javascript"  # or "go", "docker", "kubernetes", etc.
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/$INSTRUCTION_NAME.instructions.md" \
  -o ".github/instructions/$INSTRUCTION_NAME.instructions.md"
```

## Features

- **GitHub Official Format**: Uses `.github/copilot-instructions.md` and `.github/instructions/*.instructions.md`
- **Scoped Instructions**: Technology-specific instructions with `applyTo` frontmatter
- **File Targeting**: Instructions only apply to relevant file types
- **Modular Design**: Mix and match technologies as needed
- **VS Code Compatible**: Full support for advanced scoped instructions
