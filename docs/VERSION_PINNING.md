# Dependency Version Pinning Strategy

Pinning dependency versions ensures reproducibility, prevents unexpected breaking changes, and enables controlled upgrades.

## Overview

- **Benefits**: Reproducible builds, security control, prevents surprises in production
- **Cost**: Requires active dependency management
- **Strategy**: Pin major.minor versions, allow patch updates

## Terraform Provider Versions

### Current Pinning

```hcl
# ✅ Current - Pinned to major.minor (allows patch updates)
terraform {
  required_version = ">= 1.6.0, < 2.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Allows 5.0.x, 5.1.x, etc., but not 6.0
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
```

### Version Constraint Syntax

| Constraint | Example | Description |
|-----------|---------|-------------|
| `~>` | `~> 5.0` | >= 5.0, < 6.0 (right-most changes) |
| `>=, <=` | `>= 5.0, < 6.0` | Range (same as above) |
| `=` | `= 5.45.0` | Exact version only (not recommended) |
| No version | (default) | Latest version (not recommended) |

### Recommended Versioning

```hcl
# ✅ Good: Allows patch updates, prevents major version jumps
terraform {
  required_version = ">= 1.6.0, < 2.0"  # Current: 1.6+
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"      # Current: 5.45.0
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"      # Current: 5.36.0
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"      # Current: 3.15.0
    }
  }
}
```

## Locked Provider Versions

Terraform automatically creates `.terraform.lock.hcl` which locks exact versions:

```bash
# Always commit .terraform.lock.hcl to version control
git add .terraform.lock.hcl
git commit -m "chore(terraform): lock provider versions"

# This ensures everyone uses exact same versions
cat .terraform.lock.hcl

# Output example:
# provider "registry.terraform.io/hashicorp/aws" {
#   version     = "5.45.0"
#   constraints = "~> 5.0"
#   hashes = [
#     "h1:...",
#   ]
# }
```

### Upgrading Providers

```bash
# Update all providers to latest within constraints
terraform init -upgrade

# Or update specific provider
terraform init -upgrade -lockfile=readonly

# Then commit new lock file
git add .terraform.lock.hcl
git commit -m 'chore(terraform): upgrade provider versions'
```

## Python Dependencies

### requirements.txt Format

```txt
# ✅ Pinned to exact patch version (reproducible)
flask==2.3.5
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
boto3==1.28.85
python-dotenv==1.0.0

# ✅ Or pin major.minor (allow patch updates)
# flask>=2.3.0,<2.4
# sqlalchemy>=2.0.0,<2.1

# ❌ Never use this (unpredictable)
# flask
# flask>=2.3.0
```

### Creating requirements.txt

```bash
# Capture current environment
pip freeze > requirements.txt

# Or use pip-sync for reproducibility
pip install pip-tools
pip-compile requirements.in --output-file requirements.txt
```

## Docker Image Versions

### Pinning Base Images

```dockerfile
# ❌ BAD - Unpredictable, security issues
FROM python:latest
FROM node:latest
FROM ubuntu:22.04  # Can change daily

# ✅ Good - Specific version (reproducible)
FROM python:3.11.5-alpine
FROM node:18.18.0-alpine
FROM ubuntu:22.04.1
```

### Image Version Strategy

```dockerfile
# Current best practice:
# Use image:version-variant format

# Python
FROM python:3.11.5-alpine        # ~7MB, small, fast
FROM python:3.11.5-slim          # ~145MB, minimal + essentials
FROM python:3.11.5                # ~945MB, full Python distro

# Node.js
FROM node:18.18.0-alpine         # ~165MB
FROM node:18.18.0                # ~1.1GB

# AWS (Lambda/general)
FROM public.ecr.aws/lambda/python:3.11.2024.01.17.13
```

### Checking Image Versions

```bash
# Pull specific version
docker pull python:3.11.5-alpine

# List available tags
curl https://registry.hub.docker.com/v2/repositories/library/python/tags \
  | jq '.results[].name' | head -20

# Or use skopeo
skopeo list-tags docker://python | head -20
```

## GitHub Actions Versions

### Pinning Action Versions

```yaml
# ✅ Good - Pinned to major version
uses: actions/checkout@v4
uses: actions/setup-python@v4
uses: hashicorp/setup-terraform@v2

# ✅ Also good - Pinned to specific commit
uses: actions/checkout@1234567abcdefg

# ❌ Bad - Latest (security risk)
uses: actions/checkout@latest
uses: some-action  # No version specified
```

### Checking Action Versions

```bash
# Go to GitHub Action page
# Example: https://github.com/actions/checkout/releases

# Or check action.yml
curl https://raw.githubusercontent.com/actions/checkout/main/action.yml
```

## Node.js Dependencies

### package.json Pinning

```json
{
  "dependencies": {
    "express": "4.18.2",
    "dotenv": "16.3.1"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "eslint": "^8.50.0"
  }
}
```

### package-lock.json

```bash
# Lock exact versions
npm ci  # Use package-lock.json (not package.json)

# NOT: npm install (can update lock file)

# Commit both files
git add package.json package-lock.json
git commit -m 'chore(deps): add dependencies'
```

## Version Update Process

### Scheduled Updates

```bash
# 1. Create update branch on schedule (weekly)
git checkout -b deps/update-$(date +%Y%m%d)

# 2. Update dependencies
# Python
pip list --outdated
pip install --upgrade <package>
pip freeze > requirements.txt

# Node.js
npm outdated
npm update

# Terraform
cd terraform/environments/dev
terraform init -upgrade

# 3. Run full test suite
pytest -v
npm test
make validate-all

# 4. Commit updates
git add .
git commit -m 'chore(deps): update dependency versions'

# 5. Create PR for review
git push origin deps/update-$(date +%Y%m%d)
# Open PR in GitHub UI
```

### Major Version Upgrades

Require explicit review and testing:

```bash
# 1. Create feature branch
git checkout -b feat/upgrade-terraform-v2

# 2. Update version constraint
# In main.tf change: required_version = ">= 2.0, < 3.0"

# 3. Review breaking changes
# https://www.terraform.io/upgrade-guides/

# 4. Test thoroughly
make validate-all
cd terraform/environments/dev && terraform plan

# 5. Document migration
# Update README.md with migration steps

# 6. Submit for review (requires 2+ approvals)
```

## Monitoring for Updates

### Dependabot (GitHub)

Enable automatic dependency update PRs:

```yaml
# .github/dependabot.yml
version: 2
updates:
  # Python dependencies
  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "03:00"
    reviewers:
      - "guste"
    assignees:
      - "guste"
    labels:
      - "dependencies"
    open-pull-requests-limit: 10

  # Docker base images
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
    reviewers:
      - "devops-team"

  # GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    reviewers:
      - "devops-team"
```

### Renovate (Alternative)

More powerful, fine-grained control:

```json
// renovate.json
{
  "extends": ["config:base"],
  "schedule": ["before 3am on Monday"],
  "python": {
    "enabled": true
  },
  "docker": {
    "enabled": true,
    "minor": {
      "enabled": false
    }
  },
  "terraform": {
    "enabled": true
  }
}
```

## Security Scanning

### Detect Vulnerable Versions

```bash
# Python
pip install safety
safety check
# OR
pip install bandit
bandit -r app/

# Node.js
npm audit
npm audit fix

# Docker images
docker scan python:3.11.5-alpine

# Terraform (via tfsec)
tfsec terraform/
```

## Version Documentation

Create VERSION file:

```
# VERSION file in repo root
VERSION=1.2.3
TERRAFORM_MINIMUM=1.6.0
PYTHON_MINIMUM=3.11
NODE_MINIMUM=18.0.0
```

Reference in CI/CD:

```bash
#!/bin/bash
VERSION=$(cat VERSION | grep "^VERSION=" | cut -d= -f2)
TERRAFORM_MIN=$(cat VERSION | grep "^TERRAFORM_MINIMUM=" | cut -d= -f2)

terraform -version | grep ">= $TERRAFORM_MIN"
```

## Compatibility Matrix

Create documentation for supported versions:

```markdown
# Supported Versions

## Infrastructure

| Component | Version | EOL | Status |
|-----------|---------|-----|--------|
| Terraform | 1.6.x | Nov 2025 | Supported ✅ |
| Terraform | 1.5.x | Feb 2025 | Sunset ⚠️ |
| AWS Provider | 5.x | 2025-Q2 | Supported ✅ |

## Application Runtime

| Component | Version | Support Period | Status |
|-----------|---------|-----------------|--------|
| Python | 3.11 | Oct 2027 | Supported ✅ |
| Python | 3.10 | Oct 2026 | Supported ✅ |
| Python | 3.9 | Oct 2025 | Security fixes only |
| Node.js | 18.x | Apr 2025 | Supported ✅ |
| Node.js | 16.x | Sep 2023 | EOL ❌ |

## Database

| Service | Version | Status |
|---------|---------|--------|
| PostgreSQL | 15.x | Supported ✅ |
| PostgreSQL | 14.x | Supported ✅ |
| PostgreSQL | 13.x | Supported ✅ |
```

## Rollback Strategy

If version update causes issues:

```bash
# 1. Identify problematic version
git log --oneline requirements.txt | head -5

# 2. Revert to previous version
git checkout HEAD~1 requirements.txt

# 3. Test with previous version
pytest -v

# 4. Commit the revert
git commit -am "revert(deps): downgrade due to incompatibility"

# 5. Open issue to track problem
# "Investigate compatibility with package v2.1.0"
```

## Best Practices Summary

1. **Always pin versions** for reproducibility
2. **Update weekly** to stay current with patches
3. **Test before deploying** updated versions
4. **Monitor for security issues** (CVEs)
5. **Document compatibility** between components
6. **Have a rollback plan** for problematic updates
7. **Use tools** (Dependabot, Renovate, `safety check`)
8. **Review changelogs** before major updates
9. **Stagger updates** (don't update everything at once)
10. **Automate checks** (CI/CD validates version constraints)

## References

- [Terraform Registry](https://registry.terraform.io/)
- [Python Package Index (PyPI)](https://pypi.org/)
- [npm Registry](https://www.npmjs.com/)
- [Docker Hub](https://hub.docker.com/)
- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [OWASP Vulnerable Dependencies](https://owasp.org/www-project-dependency-check/)
