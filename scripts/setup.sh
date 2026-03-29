#!/bin/bash
# ==============================================
# Setup Script - AWS Infrastructure Project
# ==============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}   AWS Infrastructure Project - Setup Script    ${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform not found. Please install Terraform >= 1.6.0${NC}"
    echo "   https://www.terraform.io/downloads"
    exit 1
fi

TF_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
echo -e "${GREEN}✅ Terraform ${TF_VERSION} found${NC}"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found. Please install AWS CLI${NC}"
    echo "   https://aws.amazon.com/cli/"
    exit 1
fi

AWS_VERSION=$(aws --version | cut -d' ' -f1 | cut -d'/' -f2)
echo -e "${GREEN}✅ AWS CLI ${AWS_VERSION} found${NC}"

# Check AWS credentials
echo ""
echo -e "${YELLOW}Checking AWS credentials...${NC}"

if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo -e "${GREEN}✅ AWS credentials configured (Account: ${ACCOUNT_ID})${NC}"
else
    echo -e "${RED}❌ AWS credentials not configured${NC}"
    echo "   Run: aws configure"
    exit 1
fi

# Check Git
if ! command -v git &> /dev/null; then
    echo -e "${RED}❌ Git not found. Please install Git${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Git found${NC}"

echo ""
echo -e "${GREEN}All prerequisites met!${NC}"
echo ""

# Environment selection
echo -e "${YELLOW}Select environment to initialize:${NC}"
echo "  1) dev"
echo "  2) staging"
echo "  3) prod"
echo ""
read -p "Enter choice [1-3]: " env_choice

case $env_choice in
    1) ENV="dev" ;;
    2) ENV="staging" ;;
    3) ENV="prod" ;;
    *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
esac

echo ""
echo -e "${YELLOW}Initializing ${ENV} environment...${NC}"

# Navigate to environment
cd "terraform/environments/${ENV}"

# Initialize Terraform
echo -e "${YELLOW}Running terraform init...${NC}"
terraform init

# Validate
echo -e "${YELLOW}Running terraform validate...${NC}"
terraform validate

# Format check
echo -e "${YELLOW}Checking terraform format...${NC}"
terraform fmt -check -recursive ../../

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}   Setup Complete!                              ${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Review terraform/environments/${ENV}/variables.tf"
echo "  2. Create a terraform.tfvars file with your values"
echo "  3. Run: terraform plan"
echo "  4. Run: terraform apply"
echo ""
echo -e "${YELLOW}For CI/CD setup:${NC}"
echo "  1. Create IAM OIDC provider for GitHub Actions"
echo "  2. Configure repository secrets in GitHub"
echo "  3. Enable branch protection rules"
echo ""
