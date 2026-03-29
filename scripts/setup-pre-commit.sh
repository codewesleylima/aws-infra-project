#!/bin/bash
# ============================================
# Pre-commit Hooks Setup Script
# ============================================
# This script installs and configures git pre-commit hooks
# for automated code quality checks before commits
#
# Usage: ./scripts/setup-pre-commit.sh

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          Setting up Git Pre-Commit Hooks                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================
# Check if pre-commit is installed
# ============================================
if ! command -v pre-commit &> /dev/null; then
    echo "⚠️  pre-commit not found. Installing..."
    
    if command -v pip &> /dev/null; then
        pip install pre-commit
    elif command -v pip3 &> /dev/null; then
        pip3 install pre-commit
    else
        echo "❌ Error: pip/pip3 not found. Please install pre-commit manually:"
        echo "   - macOS: brew install pre-commit"
        echo "   - Linux: pip install pre-commit"
        echo "   - Windows: pip install pre-commit"
        exit 1
    fi
else
    echo "✅ pre-commit is installed"
fi

# ============================================
# Check other required tools
# ============================================
echo ""
echo "Checking for required tools..."
echo ""

MISSING_TOOLS=()

# Check for terraform
if ! command -v terraform &> /dev/null; then
    echo "⚠️  terraform not found (optional but recommended)"
    MISSING_TOOLS+=("terraform")
else
    echo "✅ terraform found: $(terraform version | head -1)"
fi

# Check for tflint
if ! command -v tflint &> /dev/null; then
    echo "⚠️  tflint not found (optional but recommended)"
    MISSING_TOOLS+=("tflint")
else
    version=$(tflint version | grep version | awk '{print $2}')
    echo "✅ tflint found: $version"
fi

# Check for trivy
if ! command -v trivy &> /dev/null; then
    echo "⚠️  trivy not found (optional security scanner)"
    MISSING_TOOLS+=("trivy")
else
    echo "✅ trivy found: $(trivy version | head -1)"
fi

# Check for shellcheck
if ! command -v shellcheck &> /dev/null; then
    echo "⚠️  shellcheck not found (optional for shell scripts)"
    MISSING_TOOLS+=("shellcheck")
else
    echo "✅ shellcheck found"
fi

# Check for yamllint
if ! command -v yamllint &> /dev/null; then
    echo "⚠️  yamllint not found (optional for YAML files)"
    MISSING_TOOLS+=("yamllint")
else
    echo "✅ yamllint found"
fi

# ============================================
# Install pre-commit hooks
# ============================================
echo ""
echo "Installing pre-commit hooks..."
cd "$PROJECT_ROOT"
pre-commit install
echo "✅ Pre-commit hooks installed"

# ============================================
# Optional: Run pre-commit on all files
# ============================================
echo ""
read -p "Would you like to run pre-commit checks on all files now? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Running pre-commit on all files..."
    pre-commit run --all-files || {
        echo ""
        echo "⚠️  Some checks failed or need fixing"
        echo "Run 'pre-commit run --all-files' to see details"
    }
fi

# ============================================
# Summary & Next Steps
# ============================================
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                      Setup Complete ✅                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Pre-commit hooks are now installed and will run automatically on:"
echo "  - git commit (before commit is finalized)"
echo "  - git push (optional, if configured)"
echo ""
echo "Common commands:"
echo "  pre-commit run --all-files    - Run checks on all files"
echo "  pre-commit run --files <file> - Run checks on specific file"
echo "  pre-commit autoupdate         - Update hook versions"
echo "  pre-commit uninstall          - Remove hooks"
echo ""

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo "📦 Recommended installs for full functionality:"
    for tool in "${MISSING_TOOLS[@]}"; do
        case $tool in
            terraform)
                echo "   terraform: https://www.terraform.io/downloads"
                ;;
            tflint)
                echo "   tflint: https://github.com/terraform-linters/tflint"
                ;;
            trivy)
                echo "   trivy: https://github.com/aquasecurity/trivy"
                ;;
            shellcheck)
                echo "   shellcheck: https://www.shellcheck.net/"
                ;;
            yamllint)
                echo "   yamllint: pip install yamllint"
                ;;
        esac
    done
    echo ""
fi

echo "📖 For more info, see the pre-commit documentation:"
echo "   https://pre-commit.com/"
echo ""
