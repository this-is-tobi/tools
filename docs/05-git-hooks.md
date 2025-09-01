# Git Hooks

This section provides a collection of Git hooks to enforce code quality, commit conventions, and security practices in your repositories.

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
