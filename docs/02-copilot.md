# Copilot

## Available instructions

- [Consolidated Instructions](../copilot/copilot-instructions.md) - All technologies in one file
- [JavaScript/TypeScript](../copilot/instructions/javascript.instructions.md) - Scoped to JS/TS files
- [Go](../copilot/instructions/go.instructions.md) - Scoped to Go files
- [Kubernetes/Helm](../copilot/instructions/kubernetes.instructions.md) - Scoped to K8s YAML files
- [GitHub Actions](../copilot/instructions/github-actions.instructions.md) - Scoped to workflow files
- [Docker](../copilot/instructions/docker.instructions.md) - Scoped to Dockerfiles
- [Bash/Shell](../copilot/instructions/shell.instructions.md) - Scoped to shell scripts
- [General Development](../copilot/instructions/general.instructions.md) - Universal practices

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
TECHNOLOGY="javascript"  # or "go", "docker", "kubernetes", etc.
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/copilot/instructions/$TECHNOLOGY.instructions.md" \
  -o ".github/instructions/$TECHNOLOGY.instructions.md"
```

## Features

- **GitHub Official Format**: Uses `.github/copilot-instructions.md` and `.github/instructions/*.instructions.md`
- **Scoped Instructions**: Technology-specific instructions with `applyTo` frontmatter
- **File Targeting**: Instructions only apply to relevant file types
- **Modular Design**: Mix and match technologies as needed
- **VS Code Compatible**: Full support for advanced scoped instructions
