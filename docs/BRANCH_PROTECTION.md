# GitHub Branch Protection Configuration

This directory contains configuration for GitHub branch protection rules that enforce code quality and security standards.

## Overview

Branch protection rules prevent direct pushes to critical branches and require pull request reviews, status checks, and up-to-date branches before merging.

## Configuration

### Main Branch - `main` (Production)

**Location:** `.github/branch-protection-rules.json` (for reference; configure in GitHub UI)

**Requirements:**
1. ✅ At least 2 approving reviews required
2. ✅ Dismiss stale pull request approvals when new commits are pushed
3. ✅ Require status checks to pass before merging:
   - `terraform/validate`
   - `terraform/security-scan`
   - `ci/lint`
4. ✅ Require branches to be up to date before merging
5. ✅ Require signed commits
6. ✅ Include administrators in restrictions
7. ✅ Restrict who can push to matching branches
8. ✅ Auto-delete head branches on merge

### Staging Branch - `staging` (Pre-production)

**Requirements:**
1. ✅ At least 1 approving review required
2. ✅ Dismiss stale pull request approvals
3. ✅ Require status checks to pass:
   - `terraform/validate`
4. ✅ Require branches to be up to date
5. ✅ Auto-delete head branches on merge

### Development Branch - `develop` (Development)

**Requirements:**
1. ✅ At least 1 approving review required
2. ✅ Require status checks to pass:
   - `terraform/validate`

## How to Configure

### Method 1: GitHub UI (Recommended for initial setup)

1. Navigate to **Settings** → **Branches**
2. Click **"Add rule"** for each branch (main, staging, develop)
3. Enter branch name pattern (e.g., `main`, `staging`)
4. Configure permissions:
   - ✅ Require pull request reviews before merging
   - ✅ Number of approvals: 2 (main), 1 (staging/develop)
   - ✅ Dismiss stale pull request approvals
   - ✅ Require status checks to pass
   - ✅ Require branches to be up to date
   - ✅ Require signed commits (main only)
   - ✅ Include administrators (main only)
   - ✅ Restrict who can push to matching branches (main)
   - ✅ Auto-delete head branches

### Method 2: GitHub API (for automation)

```bash
#!/bin/bash
# Configure branch protection for 'main' branch

OWNER="your-org"
REPO="aws-infra-project"
BRANCH="main"
GITHUB_TOKEN="your-token"

curl -X PUT \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$OWNER/$REPO/branches/$BRANCH/protection \
  -d '{
    "required_status_checks": {
      "strict": true,
      "contexts": ["terraform/validate", "terraform/security-scan", "ci/lint"]
    },
    "required_pull_request_reviews": {
      "dismissal_restrictions": {},
      "dismiss_stale_reviews": true,
      "require_code_owner_reviews": true,
      "required_approving_review_count": 2
    },
    "enforce_admins": true,
    "required_linear_history": false,
    "allow_force_pushes": false,
    "allow_deletions": false,
    "require_conversation_resolution": true
  }'
```

### Method 3: Terraform (Infrastructure as Code)

```hcl
# terraform/github-provider.tf
terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}

# Main branch protection rule
resource "github_branch_protection" "main" {
  repository_id            = github_repository.aws_infra.node_id
  pattern                  = "main"
  enforce_admins           = true
  require_signed_commits   = true
  required_linear_history  = false
  
  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = true
    required_approving_review_count = 2
  }

  required_status_checks {
    strict   = true
    contexts = [
      "terraform/validate",
      "terraform/security-scan",
      "ci/lint"
    ]
  }
}

# Staging branch protection rule
resource "github_branch_protection" "staging" {
  repository_id  = github_repository.aws_infra.node_id
  pattern        = "staging"
  enforce_admins = true

  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = false
    required_approving_review_count = 1
  }

  required_status_checks {
    strict   = true
    contexts = ["terraform/validate"]
  }
}
```

## Status Checks

The following GitHub Actions workflows are required to pass before merge:

### terraform/validate
- Validates Terraform configuration syntax
- Runs `terraform validate` on all environments
- Location: `.github/workflows/terraform-validate.yml`

### terraform/security-scan
- Scans Terraform for security issues
- Uses Tfsec/Trivy for scanning
- Location: `.github/workflows/terraform-security.yml`

### ci/lint
- Lints code style
- Checks for formatting issues
- Runs pre-commit hooks
- Location: `.github/workflows/lint.yml`

## Code Ownership

Create a `CODEOWNERS` file to automatically request reviews from specific people/teams:

```
# CODEOWNERS file in repository root

# Terraform configuration
/terraform/                      @platform-team
/terraform/modules/rds/         @database-team
/terraform/modules/kms/         @security-team

# CI/CD
/.github/workflows/               @devops-team

# Documentation
/docs/                            @tech-docs-team
```

## Manual Review Checklist

When reviewing PRs targeting `main` or `staging`, ensure:

- [ ] **Code Quality**
  - [ ] Follows Terraform best practices
  - [ ] No hardcoded values or secrets
  - [ ] Proper variable validation
  - [ ] Clear variable descriptions

- [ ] **Testing**
  - [ ] Terraform plan looks correct
  - [ ] No unexpected resource deletions
  - [ ] State file consistency
  - [ ] No breaking changes

- [ ] **Security**
  - [ ] No open security groups (0.0.0.0/0 only where necessary)
  - [ ] Encryption enabled (RDS, S3, EBS)
  - [ ] IAM permissions follow least privilege
  - [ ] No public endpoints where not needed

- [ ] **Documentation**
  - [ ] README updated for new modules/variables
  - [ ] Comments explain complex logic
  - [ ] ARCHITECTURE.md updated if major changes

- [ ] **CI/CD Pipeline Status**
  - [ ] All GitHub Actions workflows passing
  - [ ] No merge conflicts
  - [ ] Branch is up to date with base branch

## PR Title Convention

```
feat(terraform): add new security group module
fix(rds): increase storage allocation
docs(architecture): update deployment diagram
chore(ci): update GitHub Actions versions
```

Prefixes:
- `feat:` - New feature or module
- `fix:` - Bug fix or correction
- `docs:` - Documentation improvements
- `chore:` - Maintenance, dependencies, CI/CD
- `refactor:` - Code restructuring without functional change
- `test:` - Test additions or modifications
- `perf:` - Performance improvements

## Enforcement Strategy

### For Developers

1. Create a feature branch from `develop`
2. Make changes locally
3. Push to remote feature branch
4. Open a pull request to `develop`
5. Address review comments
6. Once approved, merge and auto-delete branch

### For Release Process

1. Create release branch from `develop` (naming: `release/v1.2.0`)
2. Update version numbers and CHANGELOG
3. Open PR from release branch to `staging`
4. After review and testing: merge to `staging`
5. Automated deployment to staging environment
6. After validation: create PR from `staging` to `main`
7. At least 2 approvals required (core maintainers)
8. Automated deployment to production

### For Hotfixes

1. Create hotfix branch from `main` (naming: `hotfix/issue-description`)
2. Make fix and commit
3. Open PR to `main` (requires 2 approvals + all checks passing)
4. After merge: create PR from `main` back to `develop` (fast-track merge)

## Exceptions & Overrides

### When to Request Exception

Exceptions to branch protection are rare and require:
1. **Documented Reason:** Why normal process can't be followed
2. **Emergency Authority:** Approval from 2+ core maintainers
3. **Audit Trail:** All exceptions logged and reviewed quarterly

### Emergency Pushes (Last Resort)

If GitHub infrastructure fails and changes are needed:
1. Document the issue and required changes
2. Get approval from at least 2 team leads
3. Note the commit hash that was pushed directly
4. Post-merge: Send PR to correct the branch
5. Notify team of incident in postmortem

## Troubleshooting

### PR Blocked with "Required status checks pending"

**Solution:**
1. Wait for GitHub Actions workflows to complete
2. Check workflow status in "Checks" tab
3. If failed, click "Details" to see logs and fix issues
4. Commit fixes to your branch (workflow runs automatically)

### "Branch out of date" Error

**Solution:**
```bash
git fetch origin
git rebase origin/develop
git push --force-with-lease origin your-feature-branch
```

### Can't Merge Due to Admin Enforcement

**Solution:**
1. Ensure all status checks pass (green checkmarks)
2. Wait for required 2 approvals from code owners
3. No other pending reviewers
4. Branch must be up to date with main/staging

### "Require signed commits" Error

**Solution:**
```bash
# Configure GPG signing
git config --global user.signingkey YOUR_KEY_ID
git config --global commit.gpgsign true

# Commit with signature
git commit -S -m "your message"
```

## Monitoring Branch Protection

### Check Current Rules

```bash
# List all protected branches
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/OWNER/REPO/branches

# Get specific branch protection rules
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/OWNER/REPO/branches/main/protection
```

### Audit Protection Changes

1. Navigate to **Settings** → **Audit Log**
2. Filter for "branch protection" changes
3. Review who modified rules and when

## Best Practices

1. **Don't merge without review:** Code review catches issues automated checks miss
2. **Dismiss stale reviews:** Ensure reviews are current after new commits
3. **Keep branch up to date:** Prevents merge conflicts and unexpected interactions
4. **Test locally first:** Run checks locally before pushing to save CI/CD time
5. **Review the diff:** Don't just click "Approve" - examine the actual changes
6. **Require signed commits:** Adds non-repudiation to production changes
7. **Include admins:** Admins aren't exempt from the rules they set
8. **Restrict direct pushes:** Only allow merges through PRs

## References

- [GitHub Branch Protection Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches)
- [GitHub API - Branch Protection](https://docs.github.com/en/rest/branches/branch-protection)
- [GitHub Actions Status Checks](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/about-status-checks)
- [Terraform GitHub Provider](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/branch_protection)
