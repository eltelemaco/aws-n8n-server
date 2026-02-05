SHELL := /bin/bash

# Directories
BOOTSTRAP_DIR := infra/bootstrap-hcp
PROD_DIR := infra/live/prod

.PHONY: help bootstrap bootstrap-init bootstrap-plan bootstrap-apply \
        init plan apply destroy \
        fmt validate clean

# Default target
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Bootstrap (HCP Terraform workspace - local state):"
	@echo "  bootstrap-init    Initialize bootstrap terraform"
	@echo "  bootstrap-plan    Plan bootstrap changes"
	@echo "  bootstrap-apply   Apply bootstrap (create HCP workspace)"
	@echo "  bootstrap         Run init + apply for bootstrap"
	@echo ""
	@echo "Main Infrastructure (remote state in HCP):"
	@echo "  init              Initialize main terraform"
	@echo "  plan              Plan infrastructure changes"
	@echo "  apply             Apply infrastructure changes"
	@echo "  destroy           Destroy infrastructure (with confirmation)"
	@echo ""
	@echo "Development:"
	@echo "  fmt               Format all terraform files"
	@echo "  validate          Validate terraform configuration"
	@echo "  clean             Remove .terraform directories"
	@echo ""

# =============================================================================
# Bootstrap (HCP Terraform workspace creation - uses local state)
# =============================================================================

bootstrap-init:
	terraform -chdir=$(BOOTSTRAP_DIR) init

bootstrap-plan:
	terraform -chdir=$(BOOTSTRAP_DIR) plan

bootstrap-apply:
	terraform -chdir=$(BOOTSTRAP_DIR) apply

bootstrap: bootstrap-init bootstrap-apply

# =============================================================================
# Main Infrastructure (uses HCP Terraform remote state)
# =============================================================================

init:
	terraform -chdir=$(PROD_DIR) init

plan:
	terraform -chdir=$(PROD_DIR) plan

apply:
	terraform -chdir=$(PROD_DIR) apply

destroy:
	@echo "WARNING: This will destroy all infrastructure including:"
	@echo "  - EC2 instance and EIP"
	@echo "  - VPC, subnet, and networking"
	@echo "  - Security groups"
	@echo "  - IAM roles and policies"
	@echo ""
	@echo "NOTE: SSM parameters may have prevent_destroy enabled."
	@echo ""
	@read -p "Are you sure you want to destroy? [y/N] " confirm && \
		[ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] && \
		terraform -chdir=$(PROD_DIR) destroy || \
		echo "Destroy cancelled."

# =============================================================================
# Development helpers
# =============================================================================

fmt:
	terraform fmt -recursive .

validate: init
	terraform -chdir=$(PROD_DIR) validate

clean:
	rm -rf $(BOOTSTRAP_DIR)/.terraform
	rm -rf $(PROD_DIR)/.terraform
	@echo "Cleaned .terraform directories"
	@echo "NOTE: State files were not removed."
