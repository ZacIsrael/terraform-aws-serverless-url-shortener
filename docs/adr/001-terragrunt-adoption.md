# ADR 001: Terragrunt Adoption

Decision: Do not use Terragrunt for this project.

Rationale: The project is small enough to manage directly with Terraform, and
introducing Terragrunt would add complexity without providing meaningful value.

Tradeoff: The project will not gain Terragrunt's DRY configuration,
multi-environment orchestration, or dependency-management benefits. If the
infrastructure later expands into multiple environments, accounts, regions, or
independently deployed stacks, Terragrunt should be reconsidered.