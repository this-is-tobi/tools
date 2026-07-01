---
applyTo: "**/*.{tf,tfvars,hcl}"
---

# Terraform & Infrastructure as Code Instructions

You are an expert in Terraform and cloud infrastructure management.

## Project Structure

```
infra/
├── modules/          # Reusable internal modules
│   └── <name>/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
├── environments/     # Per-environment root configurations
│   ├── dev/
│   ├── staging/
│   └── prod/
├── versions.tf       # Required providers and TF version constraint
└── backend.tf        # Remote state configuration
```

- Separate module development from environment instantiation
- Never write business logic in root modules; delegate to child modules
- Keep root modules thin: they only wire modules together and set environment-specific values

## Code Style

- Use 2-space indentation
- Use `snake_case` for all resource names, variables, and outputs
- Group related resources in dedicated files (e.g., `iam.tf`, `networking.tf`, `storage.tf`)
- Order blocks: `terraform` > `provider` > `data` > `locals` > `resource` > `output`
- Always include `description` for every `variable` and `output`
- Use `locals` to reduce repetition; avoid duplicating expressions

## Versioning & Providers

- Pin the Terraform CLI version with `required_version` in `versions.tf`
- Pin all provider versions to a `~>` minor constraint minimum; pin exact in CI
- Use the official registry source for providers: `registry.terraform.io/<namespace>/<provider>`
- Commit the `.terraform.lock.hcl` file to version control for reproducible runs

```hcl
terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
}
```

## State Management

- Always use remote state; never commit `.tfstate` files
- Enable state locking (DynamoDB for AWS, GCS for GCP)
- Use separate state files per environment and per logical component
- Restrict access to the state backend to CI/CD identities only
- Enable state encryption at rest

## Variables & Secrets

- Never hardcode secrets, passwords, or API keys in `.tf` or `.tfvars` files
- Use a secrets manager (Vault, AWS Secrets Manager, SOPS) and reference via data sources
- Mark sensitive variables and outputs with `sensitive = true`
- Provide `default` values only for non-sensitive, truly optional variables
- Validate variables with `validation` blocks

```hcl
variable "environment" {
  type        = string
  description = "Deployment environment name"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}
```

## Security

- Follow least-privilege for all IAM roles and policies created by Terraform
- Use `prevent_destroy = true` lifecycle on critical resources (databases, state buckets)
- Enable `ignore_changes` only for attributes managed outside Terraform (e.g., auto-scaling)
- Run `tfsec` or `checkov` in CI to catch insecure configurations
- Enable versioning and MFA-delete on state S3 buckets
- Use `terraform plan` output review gates in CI before `apply`

## Modules

- Write a `README.md` for every module (use `terraform-docs` to generate it)
- Expose only the minimum necessary outputs
- Use `object()` or `list(object())` types for complex variable shapes
- Include `examples/` directory in reusable public modules
- Version public modules using Git tags; reference exact versions

## Naming Conventions

- Resources: `<project>-<environment>-<resource-type>-<name>` (e.g., `myapp-prod-sg-web`)
- Use `tags` / `labels` on every resource for cost allocation and ownership
- Define a `local.common_tags` map and merge it into all resources

```hcl
locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "github.com/org/repo"
  }
}
```

## CI/CD Integration

- Run `terraform fmt -check` and `terraform validate` on every PR
- Run policy-as-code checks (`tfsec`, `checkov`, `OPA`) in CI
- Use `terraform plan -out=tfplan` and upload the plan as an artifact for review
- Apply only from protected CI pipelines using OIDC federation (no long-lived credentials)
- Use separate CI roles for `plan` (read-only) and `apply` (write) permissions
- Run `terraform apply` automatically only for `dev`; require manual approval for `staging`/`prod`

## Testing

- Use `terratest` (Go) or `terraform test` (native, TF 1.6+) for module tests
- Test module outputs against expected values; deploy and destroy in test environments
- Use mock providers for unit-level tests of variable validation and locals
- Include tests in the module `tests/` directory

## Common Anti-patterns to Avoid

- ❌ `count` on complex resources that may be destroyed/recreated — use `for_each` instead
- ❌ Interpolation-only expressions: `"${var.name}"` → use `var.name` directly
- ❌ `terraform taint` — use `replace` lifecycle or targeted `terraform apply -replace`
- ❌ Storing state locally (`terraform.tfstate` in the repo)
- ❌ Using `terraform_remote_state` to read another team's state — use dedicated outputs or a service registry
