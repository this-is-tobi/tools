# Git Hooks

This section provides a collection of Git hooks to enforce code quality, commit conventions, and security practices in your repositories.

## Prerequisites

**For all hooks:**
- Git 2.x or higher

**Hook-specific requirements:**
- **conventional-commit**: Pure bash, no dependencies
- **eslint-lint**: Node.js, ESLint
- **helm-lint**: Helm, chart-testing CLI
- **signed-commit**: Git with GPG signing configured
- **yaml-lint**: Python, yamllint

## Hooks List

| Name                                                               | Type         | Description                                                                                                                 | Config                                                        |
| ------------------------------------------------------------------ | ------------ | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| [conventional-commit](../git-hooks/commit-msg/conventional-commit) | `commit-msg` | *pure bash check for [conventional commit](https://www.conventionalcommits.org/en/v1.0.0/) pattern in git commit messages.* | -                                                             |
| [eslint-lint](../git-hooks/pre-commit/eslint-lint)                 | `pre-commit` | *lint js, ts and many more files using [eslint](https://github.com/eslint/eslint).*                                         | [eslint.config.js](../git-hooks/configs/eslint.config.js)     |
| [helm-lint](../git-hooks/pre-commit/helm-lint)                     | `pre-commit` | *lint helm charts using [chart-testing](https://github.com/helm/chart-testing).*                                            | [chart-testing.yaml](../git-hooks/configs/chart-testing.yaml) |
| [signed-commit](../git-hooks/pre-push/signed-commit)               | `pre-push`   | *pure bash check if commits are signed.*                                                                                    | -                                                             |
| [yaml-lint](../git-hooks/pre-commit/yaml-lint)                     | `pre-commit` | *lint yaml using [yamllint](https://github.com/adrienverge/yamllint).*                                                      | [yamllint.yaml](../git-hooks/configs/yamllint.yaml)           |

## Quick Setup

Run the following command to download the hook from the GitHub repository and install it in your current repository:

```sh
# Define the target hook, file and the URL to download from
# Replace '<git_hook>' by the name of the hook you want to copy (eg. 'conventional-commit')
HOOK_NAME="<git_hook>"
TARGET_FILE=".git/hooks/$HOOK_NAME"
URL="https://raw.githubusercontent.com/this-is-tobi/tools/main/git-hooks/$HOOK_NAME"

# Check if the target file exists
if [ -f "$TARGET_FILE" ]; then
  # File exists, download the content and remove the shebang from the first line
  curl -fsSL "$URL" | sed '1 s/^#!.*//' >> "$TARGET_FILE"
else
  # File does not exist, create the file with the downloaded content
  curl -fsSL "$URL" -o "$TARGET_FILE"
fi

# Ensure the file is executable
chmod +x "$TARGET_FILE"
```

## Multiple Hooks

### Install Multiple Hooks

```sh
HOOKS=(
  "commit-msg/conventional-commit"
  "pre-commit/eslint-lint"
  "pre-commit/yaml-lint"
)

for HOOK_PATH in "${HOOKS[@]}"; do
  HOOK_TYPE=$(dirname "$HOOK_PATH")
  HOOK_NAME=$(basename "$HOOK_PATH")
  TARGET_FILE=".git/hooks/$HOOK_TYPE"
  URL="https://raw.githubusercontent.com/this-is-tobi/tools/main/git-hooks/$HOOK_PATH"
  
  if [ -f "$TARGET_FILE" ]; then
    curl -fsSL "$URL" | sed '1 s/^#!.*//' >> "$TARGET_FILE"
  else
    curl -fsSL "$URL" -o "$TARGET_FILE"
  fi
  
  chmod +x "$TARGET_FILE"
done
```

### Combining Pre-Commit Hooks

Multiple pre-commit hooks are appended to the same file:

```sh
# First hook
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/git-hooks/pre-commit/eslint-lint" \
  -o ".git/hooks/pre-commit"
chmod +x ".git/hooks/pre-commit"

# Append additional hooks
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/git-hooks/pre-commit/yaml-lint" \
  | sed '1 s/^#!.*//' >> ".git/hooks/pre-commit"
```

## Configuration

### Conventional Commit

Validates against [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <description>
```

**Allowed types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

### ESLint

Download and customize config:

```sh
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/git-hooks/configs/eslint.config.js" \
  -o "eslint.config.js"
```

### Helm Lint

Download chart-testing config:

```sh
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/git-hooks/configs/chart-testing.yaml" \
  -o ".ct.yaml"
```

### YAML Lint

Download yamllint config:

```sh
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/git-hooks/configs/yamllint.yaml" \
  -o ".yamllint"
```

### Signed Commits

Configure GPG signing:

```sh
git config --global user.signingkey <your-gpg-key-id>
git config --global commit.gpgsign true
```

## Troubleshooting

### Hook Not Executing

- Check file is executable: `chmod +x .git/hooks/<hook-name>`
- Verify file location: `.git/hooks/<hook-name>` (no extension)
- Ensure proper shebang: `#!/usr/bin/env bash`

### Conventional Commit Errors

Valid patterns:
```sh
# Valid
git commit -m "feat: add new feature"
git commit -m "fix(api): resolve timeout"

# Invalid
git commit -m "added feature"  # Missing type
git commit -m "feat:add"       # Missing space
```

### Tool Not Found Errors

```sh
# ESLint
npm install -g eslint

# chart-testing
brew install chart-testing

# yamllint
pip install yamllint
```

### Bypassing Hooks

For emergency commits (use sparingly):
```sh
git commit --no-verify -m "message"
git push --no-verify
```
