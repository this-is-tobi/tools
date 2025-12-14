#!/bin/bash

set -e

echo "=================================================="
echo "Vault Secret Initialization Script"
echo "=================================================="
echo "Vault Address: ${VAULT_ADDR}"
echo "Namespace: ${NAMESPACE:-default}"
echo ""

# Verify dependencies
echo "Checking dependencies..."
echo "  - Vault: $(vault version 2>&1 | head -1)"
echo "  - jq: $(jq --version)"
echo ""

# Authenticate to Vault using Kubernetes auth
echo "Authenticating to Vault..."

# Get Kubernetes service account token
KUBE_TOKEN="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"

# Login to Vault
VAULT_TOKEN="$(vault write -field=token auth/kubernetes/login \
  role="${VAULT_ROLE:-vault-init-secrets}" \
  jwt="$KUBE_TOKEN")"

if [ -z "$VAULT_TOKEN" ]; then
  echo "ERROR: Failed to authenticate to Vault"
  exit 1
fi

export VAULT_TOKEN
echo "✓ Successfully authenticated to Vault"
echo ""

# Function to generate random string
generate_random() {
  length=$1
  # Use openssl for better portability (works on macOS and Linux)
  openssl rand -base64 $((length * 2)) | tr -dc 'A-Za-z0-9' | head -c "$length"
}

# Function to check if secret exists
secret_exists() {
  path=$1
  vault kv get "$path" >/dev/null 2>&1
}

# Function to replace template values with actual generated values
generate_values() {
  template_json=$1

  # Convert JSON to string for processing
  result="$template_json"

  # Replace all <random:N> placeholders (each gets unique value)
  while echo "$result" | grep -qE '<random:[0-9]+>'; do
    # Extract the first placeholder and its length
    placeholder=$(echo "$result" | grep -oE '<random:[0-9]+>' | head -1)
    length=$(echo "$placeholder" | sed -E 's/<random:([0-9]+)>/\1/')
    random_val=$(generate_random "$length")
    # Escape special characters for sed
    escaped_placeholder=$(echo "$placeholder" | sed 's/[<>:]/\\&/g')
    escaped_random=$(echo "$random_val" | sed 's/[\/&]/\\&/g')
    # Replace only the first occurrence (portable sed syntax)
    result=$(echo "$result" | sed "s/$escaped_placeholder/$escaped_random/")
  done

  # Replace all <uuid> placeholders (each gets unique value)
  while echo "$result" | grep -q '<uuid>'; do
    # Try /proc/sys/kernel/random/uuid (Linux), fallback to uuidgen (macOS)
    if [ -f /proc/sys/kernel/random/uuid ]; then
      uuid_val=$(cat /proc/sys/kernel/random/uuid)
    else
      uuid_val=$(uuidgen | tr '[:upper:]' '[:lower:]')
    fi
    # Replace only the first occurrence
    result=$(echo "$result" | sed "s/<uuid>/$uuid_val/")
  done

  # Replace all AGE key placeholders (generate once per pair)
  if echo "$result" | grep -qE '<age:(secret|public)>'; then
    # Generate age key pair once
    age_output=$(age-keygen 2>&1)
    age_secret=$(echo "$age_output" | grep '^AGE-SECRET-KEY-' | tr -d '\n')
    age_public=$(echo "$age_output" | grep '^# public key:' | sed 's/^# public key: //')

    # Escape special characters for sed
    escaped_secret=$(echo "$age_secret" | sed 's/[\/&]/\\&/g')
    escaped_public=$(echo "$age_public" | sed 's/[\/&]/\\&/g')

    # Replace all AGE placeholders
    result=$(echo "$result" | sed "s/<age:secret>/$escaped_secret/g")
    result=$(echo "$result" | sed "s/<age:public>/$escaped_public/g")
  fi

  echo "$result"
}

# Function to create or update secret with nested JSON support
init_secret() {
  path=$1
  template_data=$2

  echo "Processing secret: $path"

  # Validate template data is valid JSON
  if ! echo "$template_data" | jq empty 2>/dev/null; then
    echo "  ERROR: Invalid JSON template data"
    echo "$template_data"
    return 1
  fi

  # Generate actual values from template
  new_data_json=$(generate_values "$template_data")

  # Validate generated JSON
  if ! echo "$new_data_json" | jq empty 2>/dev/null; then
    echo "  ERROR: Failed to generate valid JSON"
    echo "$new_data_json"
    return 1
  fi

  # Check if secret exists
  if secret_exists "$path"; then
    echo "  Secret exists, merging with new data..."

    # Read existing secret
    existing_data=$(vault kv get -format=json "$path" | jq '.data.data')

    # Deep merge: existing values take precedence (preserved)
    # Only add new keys/nested paths that don't exist
    merged_data=$(echo "$existing_data" "$new_data_json" | jq -s '
      def deep_merge:
        .[0] as $existing | .[1] as $new |
        if ($existing | type) == "object" and ($new | type) == "object" then
          ($existing + $new) | to_entries | reduce .[] as $item (
            {};
            . + {
              ($item.key): (
                if $existing | has($item.key) then
                  if ($existing[$item.key] | type) == "object" and ($item.value | type) == "object" then
                    [$existing[$item.key], $item.value] | deep_merge
                  else
                    $existing[$item.key]  # Preserve existing value
                  end
                else
                  $item.value  # Add new value
                end
              )
            }
          )
        else
          $existing  # Preserve existing if not both objects
        end;

      deep_merge
    ')

    # Check if anything changed
    if [ "$existing_data" = "$merged_data" ]; then
      echo "  ✓ All keys present, no update needed"
    else
      # Show what's being added (simplified diff)
      added_count=$(echo "$existing_data" "$merged_data" | jq -s '
        def count_leaves:
          if type == "object" then
            [.[] | count_leaves] | add
          else
            1
          end;

        (.[1] | count_leaves) - (.[0] | count_leaves)
      ')

      if [ "$added_count" -gt 0 ]; then
        echo "  + Adding $added_count new key(s)"
      fi

      # Update secret with merged data using vault CLI with stdin
      if ! echo "$merged_data" | vault kv put "$path" - 2>&1; then
        echo "  ERROR: Failed to update secret"
        return 1
      fi
      echo "  ✓ Secret updated"
    fi
  else
    echo "  + Creating new secret"
    # Write secret using vault CLI with stdin (preserves nested JSON)
    if ! echo "$new_data_json" | vault kv put "$path" - 2>&1; then
      echo "  ERROR: Failed to create secret"
      return 1
    fi
    echo "  ✓ Secret created"
  fi
  echo ""
}

echo "=================================================="
echo "Initializing Secrets"
echo "=================================================="
echo ""

# Read secrets configuration from stdin or file
if [ -n "${SECRETS_FILE}" ]; then
  SECRETS_CONFIG=$(cat "${SECRETS_FILE}")
else
  SECRETS_CONFIG=$(cat)
fi

# Process each secret from the configuration
echo "$SECRETS_CONFIG" | jq -c '.[]' | while read -r secret; do
  path=$(echo "$secret" | jq -r '.path')
  data=$(echo "$secret" | jq -c '.data')
  
  init_secret "$path" "$data"
done

echo "=================================================="
echo "Secret Initialization Complete"
echo "=================================================="
echo ""
echo "Summary:"
echo "$SECRETS_CONFIG" | jq -r '.[].path | "  - " + .'
echo ""
echo "Note: Existing secrets and keys were preserved."
echo "Only missing secrets/keys were created."
