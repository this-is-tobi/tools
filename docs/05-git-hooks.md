# Git Hooks

This section provides a collection of Git hooks to enforce code quality, commit conventions, and security practices in your repositories.

## Prerequisites

**For all hooks:**
- Git 2.x or higher
- Bash 3.2 or higher (the hooks start with `#!/bin/bash`, the macOS system bash works)

**Hook-specific requirements:**
- **conventional-commit**: Pure bash, no dependencies
- **eslint-lint**: Node.js, ESLint 9 or later with a flat config (the provided config also needs `@antfu/eslint-config`)
- **helm-lint**: chart-testing CLI (`ct`) and what it runs: Helm, yamllint, yamale
- **signed-commit**: Git with commit signing configured (GPG or SSH)
- **yaml-lint**: Python, yamllint

## Hooks List

| Name                                                               | Type         | Description                                                                                                                 | Config                                                        |
| ------------------------------------------------------------------ | ------------ | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| [conventional-commit](../git-hooks/commit-msg/conventional-commit) | `commit-msg` | *pure bash check for [conventional commit](https://www.conventionalcommits.org/en/v1.0.0/) pattern in git commit messages.* | -                                                             |
| [eslint-lint](../git-hooks/pre-commit/eslint-lint)                 | `pre-commit` | *lint staged js, ts and many more files using [eslint](https://github.com/eslint/eslint).*                                  | [eslint.config.js](../git-hooks/configs/eslint.config.js)     |
| [helm-lint](../git-hooks/pre-commit/helm-lint)                     | `pre-commit` | *lint the helm charts with staged changes using [chart-testing](https://github.com/helm/chart-testing).*                    | [chart-testing.yaml](../git-hooks/configs/chart-testing.yaml) |
| [signed-commit](../git-hooks/pre-push/signed-commit)               | `pre-push`   | *pure bash check that every pushed commit is signed.*                                                                       | -                                                             |
| [yaml-lint](../git-hooks/pre-commit/yaml-lint)                     | `pre-commit` | *lint staged yaml using [yamllint](https://github.com/adrienverge/yamllint).*                                               | [yamllint.yaml](../git-hooks/configs/yamllint.yaml)           |

## Quick Setup

A hook is installed as a file named after its type (`commit-msg`, `pre-commit`, `pre-push`) in the repository hooks directory. Run the following command in your repository to download a hook and install it:

```sh
# Replace '<hook_type>/<hook_name>' by the hook you want to install (eg. 'commit-msg/conventional-commit')
HOOK_PATH="<hook_type>/<hook_name>"
# Hooks directory of the repository (follows core.hooksPath and worktrees)
HOOKS_DIR="$(git rev-parse --git-path hooks)"
TARGET_FILE="$HOOKS_DIR/$(dirname "$HOOK_PATH")"
URL="https://raw.githubusercontent.com/this-is-tobi/tools/main/git-hooks/$HOOK_PATH"

mkdir -p "$HOOKS_DIR"
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
HOOKS_DIR="$(git rev-parse --git-path hooks)"
mkdir -p "$HOOKS_DIR"

for HOOK_PATH in "${HOOKS[@]}"; do
  TARGET_FILE="$HOOKS_DIR/$(dirname "$HOOK_PATH")"
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
HOOKS_DIR="$(git rev-parse --git-path hooks)"

# First hook
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/git-hooks/pre-commit/eslint-lint" \
  -o "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"

# Append additional hooks
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/git-hooks/pre-commit/yaml-lint" \
  | sed '1 s/^#!.*//' >> "$HOOKS_DIR/pre-commit"
```

Each hook runs in its own subshell: one that has nothing to check does not stop the hooks appended after it, and the first failing hook stops the commit. Two limits when appending to a hook you did not install from here:
- an existing hook that ends with `exit` stops before the appended code runs;
- a `pre-push` hook receives the pushed refs on stdin, which can only be read once: if an existing `pre-push` hook (eg. the one `git lfs install` writes) reads it, `signed-commit` sees no ref and checks nothing. Run the other hook after `signed-commit`, or install them in separate files called from the `pre-push` file.

## Configuration

### Staged Files

The pre-commit hooks lint only what the commit contains (`git diff --cached`, added, copied, modified and renamed files):

| Hook          | Staged files checked                                                                                                  |
| ------------- | --------------------------------------------------------------------------------------------------------------------- |
| `yaml-lint`   | `*.yaml`, `*.yml`, `.yamllint`                                                                                        |
| `eslint-lint` | `*.js`, `*.cjs`, `*.mjs`, `*.jsx`, `*.ts`, `*.cts`, `*.mts`, `*.tsx`, `*.vue`, `*.json`, `*.jsonc`, `*.json5`, `*.md`, `*.yaml`, `*.yml`, `*.toml` (files the ESLint config ignores are skipped) |
| `helm-lint`   | every chart (the closest directory with a `Chart.yaml`) holding a staged change, deletions included                   |

When nothing matches, the hook prints that it skipped and lets the commit through. When files match but the linter is not installed, the hook fails with the install link.

The linters read the files from the working tree: if a file is only partly staged (`git add -p`), its unstaged edits are linted too.

### Config Files

The pre-commit hooks look for their config file in the repository root, at the path the commands below download it to. An environment variable points a hook to another file; a variable set to a missing file is an error. When the variable is unset and the default file does not exist, the tool falls back to its own config lookup.

| Hook          | Variable          | Default            | Template                                                       |
| ------------- | ----------------- | ------------------ | -------------------------------------------------------------- |
| `eslint-lint` | `ESLINT_CONFIG`   | `eslint.config.js` | [eslint.config.js](../git-hooks/configs/eslint.config.js)      |
| `helm-lint`   | `CT_CONFIG`       | `.ct.yaml`         | [chart-testing.yaml](../git-hooks/configs/chart-testing.yaml)  |
| `helm-lint`   | `CT_LINT_CONFIG`  | `.yamllint`        | [yamllint.yaml](../git-hooks/configs/yamllint.yaml)            |
| `yaml-lint`   | `YAMLLINT_CONFIG` | `.yamllint`        | [yamllint.yaml](../git-hooks/configs/yamllint.yaml)            |

Paths are relative to the repository root. Set the variables in your shell profile, or for a single commit:

```sh
YAMLLINT_CONFIG=ci/yamllint.yaml git commit -m "ci: update the workflows"
```

### Conventional Commit

Validates the subject (first line) of the message against the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>)!: <description>
```

- **Allowed types:** `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test` (the [commitlint conventional config](https://github.com/conventional-changelog/commitlint/tree/master/@commitlint/config-conventional) types)
- **Scope** (optional): letters, digits, `-`, `_`, `.`, `/`, `,` and spaces (eg. `feat(git-hooks): ...`, `fix(api/v2): ...`)
- **`!`** (optional) marks a breaking change
- Comment lines (`#`, or `core.commentChar`) and blank lines before the subject are ignored, so the editor template does not get in the way
- Subjects git writes itself are accepted as they are: `Merge ...`, `Revert "..."`, `Reapply "..."`, `fixup! ...`, `squash! ...`, `amend! ...`

### ESLint

Download and customize config, then install ESLint and the shared config in the project:

```sh
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/git-hooks/configs/eslint.config.js" \
  -o "eslint.config.js"
npm install --save-dev eslint @antfu/eslint-config
```

The hook uses `node_modules/.bin/eslint` when it exists, otherwise the `eslint` found in `PATH`.

### Helm Lint

Download chart-testing config:

```sh
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/git-hooks/configs/chart-testing.yaml" \
  -o ".ct.yaml"
```

chart-testing also lints `Chart.yaml` and `values.yaml` with yamllint: it uses `.yamllint` (see [YAML Lint](#yaml-lint)) when it exists.

The hook passes the charts to lint with `--charts`, so chart-testing skips its version increment check (`check-version-increment` only applies when `ct lint` picks the changed charts itself, eg. in CI). The provided config validates the chart maintainers: each chart needs a `maintainers` list of accounts on the host of the `origin` remote (GitHub, GitLab or Bitbucket), or set `validate-maintainers: false` in `.ct.yaml`.

### YAML Lint

Download yamllint config:

```sh
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/git-hooks/configs/yamllint.yaml" \
  -o ".yamllint"
```

The provided config ignores the Helm `templates/` directories (Go templates are not valid YAML) at any depth, and requires double quotes only on strings that are quoted.

### Signed Commits

The hook checks the commits the push sends and the remote does not have yet: for an existing branch the commits since the remote tip, for a new branch or tag the commits that are on no remote-tracking branch. Deletions are skipped. Every commit that fails is listed, then the push is refused.

A commit passes when `git log --format=%G?` reports:
- `G`: good signature;
- `U`: good signature from a key of unknown trust (a GPG key you have not marked as trusted, or an SSH key missing from the allowed signers file). The signature is valid; the hosting service matches the key to its owner when it marks the commit as verified.

It fails when the commit is not signed (`N`), the signature is bad (`B`), cannot be checked (`E`, eg. the public key is missing), has expired or was made with an expired or revoked key (`X`, `Y`, `R`).

Configure GPG signing:

```sh
git config --global user.signingkey <your-gpg-key-id>
git config --global commit.gpgsign true
```

Or SSH signing. Git can only check SSH signatures with an allowed signers file: without it, every commit is reported as unverifiable.

```sh
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true

# Allowed signers file: your email and public key
mkdir -p ~/.config/git
echo "$(git config user.email) namespaces=\"git\" $(cat ~/.ssh/id_ed25519.pub)" >> ~/.config/git/allowed_signers
git config --global gpg.ssh.allowedSignersFile ~/.config/git/allowed_signers
```

To sign the commits of a refused push, rewrite them from their base, eg. `git rebase --exec 'git commit --amend --no-edit -S' origin/main`.

## Troubleshooting

### Hook Not Executing

- Check file is executable: `chmod +x "$(git rev-parse --git-path hooks)/<hook-type>"`
- Verify file location and name: `$(git rev-parse --git-path hooks)/<hook-type>`, eg. `.git/hooks/pre-commit` (the hook type, no extension)
- Ensure proper shebang on the first line: `#!/bin/bash`

### Conventional Commit Errors

Valid patterns:
```sh
# Valid
git commit -m "feat: add new feature"
git commit -m "fix(api): resolve timeout"
git commit -m "feat(git-hooks)!: drop the old installer"

# Invalid
git commit -m "added feature"  # Missing type
git commit -m "feat:add"       # Missing space
git commit -m "feature: add"   # Unknown type
```

### Tool Not Found Errors

```sh
# ESLint (in the project)
npm install --save-dev eslint @antfu/eslint-config

# chart-testing (also needs helm, yamllint and yamale)
brew install chart-testing

# yamllint
pipx install yamllint
```

### Bypassing Hooks

For emergency commits (use sparingly):
```sh
git commit --no-verify -m "message"
git push --no-verify
```
