#!/bin/bash
# ============================================
# Infrastructure Cost Estimation Tool
# ============================================
# Generates cost estimates for Terraform infrastructure
# using Infracost or terraform estimate
#
# Usage: ./scripts/estimate-costs.sh
# Optional: ./scripts/estimate-costs.sh dev

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Parse arguments
ENVIRONMENT=${1:-"all"}
FORMAT=${2:-"table"}  # table, json, html

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          Infrastructure Cost Estimation Tool                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================
# Check for available cost estimation tools
# ============================================
if command -v infracost &> /dev/null; then
    echo "✅ Using Infracost for cost estimation"
    USE_INFRACOST=true
else
    echo "⚠️  Infracost not found. Install from: https://www.infracost.io/docs/guides/installation/"
    echo "   Falling back to manual calculation..."
    USE_INFRACOST=false
fi

echo ""

# ============================================
# Infracost-based estimation
# ============================================
if [ "$USE_INFRACOST" = true ]; then
    estimate_with_infracost() {
        local env=$1
        echo "Estimating costs for $env environment..."
        
        cd "$PROJECT_ROOT/infra/environments/$env"
        
        case $FORMAT in
            json)
                infracost breakdown --path . --format json --out-file="/tmp/infracost-$env.json"
                echo "JSON output saved to /tmp/infracost-$env.json"
                ;;
            html)
                infracost breakdown --path . --format html --out-file="/tmp/infracost-$env.html"
                echo "HTML output saved to /tmp/infracost-$env.html"
                if command -v open &> /dev/null; then
                    open "/tmp/infracost-$env.html"
                elif command -v xdg-open &> /dev/null; then
                    xdg-open "/tmp/infracost-$env.html"
                fi
                ;;
            *)
                infracost breakdown --path .
                ;;
        esac
        
        cd "$PROJECT_ROOT"
    }

    # Estimate for specified environment(s)
    case $ENVIRONMENT in
        all)
            for env in dev hom prod; do
                estimate_with_infracost "$env"
                echo ""
            done
            ;;
        *)
            estimate_with_infracost "$ENVIRONMENT"
            ;;
    esac

    # Compare costs between environments
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                   Cost Comparison                              ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    if [ -f "/tmp/infracost-dev.json" ] && [ -f "/tmp/infracost-hom.json" ] && [ -f "/tmp/infracost-prod.json" ]; then
        infracost breakdown --path "$PROJECT_ROOT/infra/environments" \
            --format table \
            2>/dev/null || true
    fi

else
    # ============================================
    # Manual cost estimation
    # ============================================
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║              Manual Cost Estimation (Approximate)              ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Sample cost data (update based on us-east-1 pricing)
    # These are approximate costs per month
    estimate_manual() {
        local env=$1
        
        case $env in
            dev)
                echo "📊 Development Environment (us-east-1) - Monthly Costs:"
                echo "   VPC (NAT Gateway, Endpoints):        ~$45"
                echo "   ECS Fargate (2 tasks × 0.25 vCPU):   ~$15"
                echo "   RDS (db.t3.micro Multi-AZ):          ~$80"
                echo "   S3 (ALB logs, storage):              ~$5"
                echo "   CloudTrail, KMS:                     ~$10"
                echo "   ────────────────────────────────────────"
                echo "   💰 Total Estimated Monthly: ~$155"
                echo "   💰 Total Estimated Annual:  ~$1,860"
                ;;
            hom)
                echo "📊 Hom Environment (us-east-1) - Monthly Costs:"
                echo "   VPC (NAT Gateway, Endpoints):        ~$45"
                echo "   ECS Fargate (3 tasks × 0.5 vCPU):    ~$35"
                echo "   RDS (db.t3.small Multi-AZ):          ~$120"
                echo "   S3 (ALB logs, storage):              ~$8"
                echo "   CloudTrail, KMS:                     ~$15"
                echo "   ────────────────────────────────────────"
                echo "   💰 Total Estimated Monthly: ~$223"
                echo "   💰 Total Estimated Annual:  ~$2,676"
                ;;
            prod)
                echo "📊 Production Environment (us-east-1) - Monthly Costs:"
                echo "   VPC (NAT Gateways × 3, Endpoints):   ~$135"
                echo "   ECS Fargate (Min 3→Max 20 × 1vCPU):  ~$75-$500"
                echo "   RDS (db.r6g.large Multi-AZ):         ~$300"
                echo "   ALB (Application Load Balancer):     ~$22"
                echo "   S3 (ALB logs, storage, archiving):   ~$15"
                echo "   CloudTrail, KMS, CloudWatch:         ~$50"
                echo "   Data Transfer (egress):              ~$20-$100"
                echo "   ────────────────────────────────────────"
                echo "   💰 Total Estimated Monthly: ~$617-$1,122"
                echo "   💰 Total Estimated Annual:  ~$7,404-$13,464"
                ;;
        esac
        echo ""
    }
    
    case $ENVIRONMENT in
        all)
            estimate_manual dev
            estimate_manual hom
            estimate_manual prod
            ;;
        *)
            estimate_manual "$ENVIRONMENT"
            ;;
    esac
    
    echo "📝 Notes:"
    echo "   - Costs are approximate and based on on-demand pricing"
    echo "   - Actual costs may vary based on usage and data transfer"
    echo "   - Reserved instances or savings plans could reduce costs 20-40%"
    echo "   - For accurate estimates, install and run Infracost"
    echo ""
    echo "🔗 Install Infracost:"
    echo "   https://www.infracost.io/docs/guides/installation/"
    echo ""
fi

# ============================================
# Optimization recommendations
# ============================================
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    Cost Optimization Tips                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "1. 🔄 Reserved Instances & Savings Plans"
echo "   - RDS: ~30-50% savings with 1-3 year commitments"
echo "   - Fargate: ~20-30% savings with 1 year plans"
echo ""
echo "2. 📊 Auto-scaling Optimization"
echo "   - Review target tracking policies for ECS"
echo "   - Set appropriate min/max capacity limits"
echo "   - Consider scheduled scaling for predictable workloads"
echo ""
echo "3. 💾 Storage & Lifecycle Optimization"
echo "   - Enable S3 Intelligent-Tiering for logs"
echo "   - Archive old CloudTrail logs to Glacier"
echo "   - Set appropriate retention policies (30-90 days)"
echo ""
echo "4. 🌐 Data Transfer Optimization"
echo "   - Use VPC endpoints instead of NAT gateway for AWS APIs"
echo "   - CloudFront for large static assets"
echo "   - Configure S3 bucket replication only when necessary"
echo ""
echo "5. 📈 Monitoring & Alerts"
echo "   - Set up AWS Budgets for cost alerts"
echo "   - Review Cost Explorer weekly"
echo "   - Enable Cost Anomaly Detection"
echo ""
echo "6. 💿 Instance Type Optimization"
echo "   - Review ECS task CPU/memory allocation"
echo "   - Switch to ARM-based Graviton2 (cheaper, good performance)"
echo "   - Downsize RDS if underutilized"
echo ""
