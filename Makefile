# ==============================================
# Makefile for Terraform AWS Infrastructure
# ==============================================
# Common Terraform operations for development and deployment
#
# Usage:
#   make help              - Show available commands
#   make validate-dev      - Validate dev environment
#   make plan-dev          - Plan changes for dev
#   make apply-dev         - Apply changes for dev
#   make fmt               - Format all terraform files
#   make init-dev          - Initialize dev backend

.PHONY: help init fmt validate plan apply destroy clean fmt-check lint test cost-estimate

# Variables
TERRAFORM := terraform
TF_DIR := terraform
ENVIRONMENTS := dev staging prod

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help:
	@echo "$(BLUE)╔════════════════════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║                   AWS Infrastructure Terraform Makefile                         ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)Initialization:$(NC)"
	@echo "  make init-dev            - Initialize Terraform backend for dev"
	@echo "  make init-staging        - Initialize Terraform backend for staging"
	@echo "  make init-prod           - Initialize Terraform backend for prod"
	@echo ""
	@echo "$(GREEN)Code Quality:$(NC)"
	@echo "  make fmt                 - Format all Terraform files"
	@echo "  make fmt-check           - Check Terraform formatting without changes"
	@echo "  make validate-dev        - Validate dev environment configuration"
	@echo "  make validate-staging    - Validate staging environment configuration"
	@echo "  make validate-prod       - Validate prod environment configuration"
	@echo "  make lint                - Run security/style linter (tfsec)"
	@echo ""
	@echo "$(GREEN)Planning & Deployment:$(NC)"
	@echo "  make plan-dev            - Plan changes for dev environment"
	@echo "  make plan-staging        - Plan changes for staging environment"
	@echo "  make plan-prod           - Plan changes for prod environment (requires approval)"
	@echo "  make apply-dev           - Apply changes for dev environment"
	@echo "  make apply-staging       - Apply changes for staging environment"
	@echo "  make apply-prod          - Apply changes for prod environment (requires approval)"
	@echo ""
	@echo "$(GREEN)Destruction:$(NC)"
	@echo "  make destroy-dev         - Destroy dev infrastructure"
	@echo "  make destroy-staging     - Destroy staging infrastructure"
	@echo "  make destroy-prod        - Destroy prod infrastructure (requires approval)"
	@echo ""
	@echo "$(GREEN)Utilities:$(NC)"
	@echo "  make clean               - Remove Terraform lock files and .terraform directories"
	@echo "  make refresh-dev         - Refresh dev state without applying changes"
	@echo "  make refresh-staging     - Refresh staging state without applying changes"
	@echo "  make refresh-prod        - Refresh prod state without applying changes"
	@echo "  make graph               - Generate and view infrastructure graph (requires graphviz)"
	@echo "  make cost-estimate       - Estimate infrastructure costs (requires infracost)"
	@echo "  make output-dev          - Show dev outputs"
	@echo "  make output-staging      - Show staging outputs"
	@echo "  make output-prod         - Show prod outputs"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make validate-dev && make plan-dev"
	@echo "  make fmt && make validate-staging"
	@echo "  make plan-prod && make apply-prod"
	@echo ""

# ============================================
# Initialize Backends
# ============================================
init-dev:
	@echo "$(BLUE)Initializing Terraform backend for dev...$(NC)"
	cd $(TF_DIR)/environments/dev && $(TERRAFORM) init -backend-config=../../backends/backend.dev.tfbackend

init-staging:
	@echo "$(BLUE)Initializing Terraform backend for staging...$(NC)"
	cd $(TF_DIR)/environments/staging && $(TERRAFORM) init -backend-config=../../backends/backend.staging.tfbackend

init-prod:
	@echo "$(BLUE)Initializing Terraform backend for prod...$(NC)"
	cd $(TF_DIR)/environments/prod && $(TERRAFORM) init -backend-config=../../backends/backend.prod.tfbackend

# ============================================
# Code Formatting & Validation
# ============================================
fmt:
	@echo "$(BLUE)Formatting all Terraform files...$(NC)"
	cd $(TF_DIR) && $(TERRAFORM) fmt -recursive

fmt-check:
	@echo "$(BLUE)Checking Terraform formatting...$(NC)"
	cd $(TF_DIR) && $(TERRAFORM) fmt -recursive -check

validate-dev:
	@echo "$(BLUE)Validating dev environment...$(NC)"
	cd $(TF_DIR)/environments/dev && $(TERRAFORM) validate

validate-staging:
	@echo "$(BLUE)Validating staging environment...$(NC)"
	cd $(TF_DIR)/environments/staging && $(TERRAFORM) validate

validate-prod:
	@echo "$(BLUE)Validating prod environment...$(NC)"
	cd $(TF_DIR)/environments/prod && $(TERRAFORM) validate

lint:
	@echo "$(BLUE)Running Terraform linter (tfsec)...$(NC)"
	@command -v tfsec >/dev/null 2>&1 || { echo "$(RED)tfsec not installed. Install with: brew install tfsec$(NC)"; exit 1; }
	tfsec $(TF_DIR)

# ============================================
# Planning
# ============================================
plan-dev: validate-dev
	@echo "$(BLUE)Planning changes for dev...$(NC)"
	cd $(TF_DIR)/environments/dev && $(TERRAFORM) plan -out=tfplan

plan-staging: validate-staging
	@echo "$(BLUE)Planning changes for staging...$(NC)"
	cd $(TF_DIR)/environments/staging && $(TERRAFORM) plan -out=tfplan

plan-prod: validate-prod
	@echo "$(RED)Planning changes for PROD - Review carefully!$(NC)"
	cd $(TF_DIR)/environments/prod && $(TERRAFORM) plan -out=tfplan

# ============================================
# Applying
# ============================================
apply-dev:
	@echo "$(BLUE)Applying changes for dev...$(NC)"
	cd $(TF_DIR)/environments/dev && $(TERRAFORM) apply tfplan

apply-staging:
	@echo "$(BLUE)Applying changes for staging...$(NC)"
	cd $(TF_DIR)/environments/staging && $(TERRAFORM) apply tfplan

apply-prod:
	@echo "$(RED)Applying changes for PROD - This requires manual approval!$(NC)"
	@echo "$(YELLOW)Are you sure? [y/N]$(NC)" && read ans && [ $${ans:-N} = y ] && \
	cd $(TF_DIR)/environments/prod && $(TERRAFORM) apply tfplan || echo "Aborted"

# ============================================
# Destruction
# ============================================
destroy-dev:
	@echo "$(YELLOW)Destroying dev infrastructure...$(NC)"
	cd $(TF_DIR)/environments/dev && $(TERRAFORM) destroy

destroy-staging:
	@echo "$(YELLOW)Destroying staging infrastructure...$(NC)"
	cd $(TF_DIR)/environments/staging && $(TERRAFORM) destroy

destroy-prod:
	@echo "$(RED)Destroying PROD infrastructure - Manual approval required!$(NC)"
	@echo "$(RED)This is a DESTRUCTIVE operation!$(NC)"
	@echo "$(YELLOW)Are you absolutely sure? [y/N]$(NC)" && read ans && [ $${ans:-N} = y ] && \
	cd $(TF_DIR)/environments/prod && $(TERRAFORM) destroy || echo "Aborted"

# ============================================
# State Management
# ============================================
refresh-dev:
	@echo "$(BLUE)Refreshing dev state...$(NC)"
	cd $(TF_DIR)/environments/dev && $(TERRAFORM) refresh

refresh-staging:
	@echo "$(BLUE)Refreshing staging state...$(NC)"
	cd $(TF_DIR)/environments/staging && $(TERRAFORM) refresh

refresh-prod:
	@echo "$(BLUE)Refreshing prod state...$(NC)"
	cd $(TF_DIR)/environments/prod && $(TERRAFORM) refresh

# ============================================
# Outputs
# ============================================
output-dev:
	@echo "$(BLUE)Dev Environment Outputs:$(NC)"
	cd $(TF_DIR)/environments/dev && $(TERRAFORM) output

output-staging:
	@echo "$(BLUE)Staging Environment Outputs:$(NC)"
	cd $(TF_DIR)/environments/staging && $(TERRAFORM) output

output-prod:
	@echo "$(BLUE)Prod Environment Outputs:$(NC)"
	cd $(TF_DIR)/environments/prod && $(TERRAFORM) output

# ============================================
# Utilities
# ============================================
clean:
	@echo "$(BLUE)Cleaning Terraform files...$(NC)"
	find $(TF_DIR) -name '.terraform' -type d -exec rm -rf {} + 2>/dev/null || true
	find $(TF_DIR) -name '.terraform.lock.hcl' -type f -delete 2>/dev/null || true
	find $(TF_DIR) -name 'tfplan' -type f -delete 2>/dev/null || true
	find $(TF_DIR) -name '*.tfstate' -type f -delete 2>/dev/null || true
	find $(TF_DIR) -name '*.tfstate.backup' -type f -delete 2>/dev/null || true
	@echo "$(GREEN)Clean complete$(NC)"

graph:
	@echo "$(BLUE)Generating infrastructure graph...$(NC)"
	@command -v dot >/dev/null 2>&1 || { echo "$(RED)graphviz not installed. Install with: brew install graphviz$(NC)"; exit 1; }
	@for env in $(ENVIRONMENTS); do \
		echo "Generating graph for $$env..."; \
		cd $(TF_DIR)/environments/$$env && $(TERRAFORM) graph | dot -Tsvg > /tmp/terraform-$$env.svg; \
		echo "Graph saved to /tmp/terraform-$$env.svg"; \
	done

cost-estimate:
	@echo "$(BLUE)Estimating infrastructure costs...$(NC)"
	@command -v infracost >/dev/null 2>&1 || { echo "$(RED)infracost not installed. Install from: https://www.infracost.io/docs/guides/installation/$(NC)"; exit 1; }
	@for env in $(ENVIRONMENTS); do \
		echo "$(BLUE)Cost estimate for $$env:$(NC)"; \
		cd $(TF_DIR)/environments/$$env && infracost breakdown --path . || true; \
	done

# ============================================
# Development Workflow Shortcuts
# ============================================
check-dev: fmt validate-dev lint
	@echo "$(GREEN)Dev environment checks passed!$(NC)"

check-staging: fmt validate-staging lint
	@echo "$(GREEN)Staging environment checks passed!$(NC)"

check-prod: fmt validate-prod lint
	@echo "$(GREEN)Prod environment checks passed!$(NC)"

check-all: fmt validate-dev validate-staging validate-prod lint
	@echo "$(GREEN)All environments checks passed!$(NC)"

.DEFAULT_GOAL := help
