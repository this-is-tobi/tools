---
applyTo: "**/*.{sh,bash,zsh}"
---

# Bash & Shell Scripting Instructions

You are an expert in Bash and shell scripting.

## Bash Best Practices

- Always use shebang: `#!/bin/bash` or `#!/usr/bin/env bash`
- Use `set -euo pipefail` for strict error handling
- Quote variables to prevent word splitting: `"$variable"`
- Use `[[ ]]` instead of `[ ]` for conditional tests
- Use functions for reusable code blocks
- Use meaningful variable and function names
- Add proper error handling and logging
- Use proper exit codes for script status

## Script Structure

- Include a header comment with script purpose and usage
- Define variables at the top of the script
- Use functions for complex operations
- Implement proper argument parsing
- Add help/usage information
- Use consistent indentation (2 or 4 spaces)
- Group related functionality together

## Error Handling

- Use `set -e` to exit on any command failure
- Use `set -u` to exit on undefined variables
- Use `set -o pipefail` to catch pipeline failures
- Implement proper error messages with line numbers
- Use trap for cleanup operations
- Check return codes explicitly when needed
- Provide meaningful error messages

## Variable Handling

- Use lowercase for local variables and uppercase for environment variables
- Use `readonly` for constants
- Quote all variable expansions: `"$var"` not `$var`
- Use `${var}` for clarity in complex expressions
- Use parameter expansion for string manipulation
- Initialize variables before use
- Use arrays for lists of items

## Function Best Practices

- Use `local` variables in functions
- Return meaningful exit codes
- Use proper parameter passing
- Include function documentation
- Keep functions focused and small
- Use descriptive function names
- Implement input validation

## File Operations

- Check if files exist before operating on them
- Use proper file permissions and ownership
- Use temporary files securely with `mktemp`
- Clean up temporary files with traps
- Use proper path handling
- Check disk space before large operations
- Use appropriate file locking when needed

## Security Considerations

- Validate all inputs
- Use `mktemp` for temporary files
- Set proper file permissions
- Avoid eval and shell injection vulnerabilities
- Use full paths for commands in scripts
- Don't store secrets in scripts
- Use proper logging without exposing sensitive data

## Performance Optimization

- Use built-in shell features instead of external commands when possible
- Avoid unnecessary subshells
- Use efficient loops and conditionals
- Process files line by line for large files
- Use appropriate data structures
- Cache expensive operations
- Use parallel processing when appropriate

## Portability

- Use POSIX-compliant features when possible
- Test on target platforms
- Handle different shell behaviors
- Use portable command options
- Check for required commands and versions
- Use appropriate feature detection

## Common Patterns

Argument Parsing:
```bash
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      exit 0
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done
```

Error Handling:
```bash
set -euo pipefail

# Cleanup function
cleanup() {
  rm -f "$temp_file"
}

# Set trap for cleanup
trap cleanup EXIT

# Error logging
log_error() {
  echo "ERROR: $*" >&2
}
```

## Script Template

```bash
#!/bin/bash
#
# Script description
# Usage: script_name [options] arguments
#

set -euo pipefail

# Constants
readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_DIR=$(dirname "$0")

# Variables
VERBOSE=false
DRY_RUN=false

# Functions
show_help() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] ARGUMENTS

Description of what the script does.

OPTIONS:
  -h, --help      Show this help message
  -v, --verbose   Enable verbose output
  -n, --dry-run   Show what would be done without executing

EXAMPLES:
  $SCRIPT_NAME example
EOF
}

log_info() {
  if [[ "$VERBOSE" == true ]]; then
    echo "INFO: $*"
  fi
}

log_error() {
  echo "ERROR: $*" >&2
}

main() {
  # Main script logic here
  log_info "Starting script execution"
  
  # Your code here
  
  log_info "Script completed successfully"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      exit 0
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      log_error "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Run main function
main "$@"
```
