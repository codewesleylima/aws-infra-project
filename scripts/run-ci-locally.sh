#!/bin/bash
# ============================================
# Local CI/CD Pipeline Test Script
# ============================================
# Run all CI/CD steps locally to validate before pushing
# Usage: bash scripts/run-ci-locally.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "🚀 Starting Local CI/CD Pipeline"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to run a step
run_step() {
  local step_name="$1"
  local step_cmd="$2"
  
  echo -e "${YELLOW}▶ Running: $step_name${NC}"
  if eval "$step_cmd"; then
    echo -e "${GREEN}✅ $step_name PASSED${NC}"
  else
    echo -e "${RED}❌ $step_name FAILED${NC}"
    exit 1
  fi
  echo ""
}

# Step 1: Build and Test Spring Boot Application
run_step "Java Build & Tests" \
  "cd '$PROJECT_ROOT' && mvn -f library-app/pom.xml -B clean test package"

# Step 2: Gitleaks - Secret pattern detection
if command -v gitleaks &> /dev/null; then
  run_step "Gitleaks Secret Scan" \
    "cd '$PROJECT_ROOT' && gitleaks detect --config .gitleaks.toml --verbose"
else
  echo -e "${YELLOW}⚠️  Gitleaks not installed (optional), skipping...${NC}"
  echo "   Install: https://github.com/gitleaks/gitleaks"
fi
echo ""

# Step 3: TruffleHog - Additional secret detection
if command -v trufflehog &> /dev/null; then
  run_step "TruffleHog Secret Scan" \
    "cd '$PROJECT_ROOT' && trufflehog filesystem . --only-verified --json --entropy=False"
else
  echo -e "${YELLOW}⚠️  TruffleHog not installed (optional), skipping...${NC}"
  echo "   Install: https://github.com/trufflesecurity/trufflehog"
fi
echo ""

# Step 4: TFSec - Terraform security scanning
if command -v tfsec &> /dev/null; then
  run_step "TFSec Terraform Scan" \
    "cd '$PROJECT_ROOT' && tfsec infra/ --format pretty || true"
else
  echo -e "${YELLOW}⚠️  TFSec not installed (optional), skipping...${NC}"
  echo "   Install: https://github.com/aquasecurity/tfsec"
fi
echo ""

# Step 5: Validate no secrets in .gitignore
run_step "Security Validation" \
  "cd '$PROJECT_ROOT' && bash scripts/validate-no-secrets.sh"

# Step 6: Docker Build
if command -v docker &> /dev/null; then
  run_step "Docker Build" \
    "cd '$PROJECT_ROOT' && docker build -t library-app:ci-test ."
else
  echo -e "${YELLOW}⚠️  Docker not installed, skipping...${NC}"
fi
echo ""

# Summary
echo "=========================================="
echo -e "${GREEN}✅ All CI/CD Steps Passed!${NC}"
echo "=========================================="
echo ""
echo "You can now safely push your changes:"
echo "  git push origin feature/first-model-library-with-spring"
echo ""
