# Local CI/CD Testing Guide

## 🎯 Overview

This guide explains how to test your changes locally **before pushing to GitHub**, avoiding CI/CD failures and wasted time waiting for GitHub Actions.

## ⚡ Quick Start

### Option 1: Complete Pipeline Test (Recommended)
```bash
make test-ci
```
This runs all CI/CD steps in sequence:
- ✅ Spring Boot unit tests
- ✅ Gitleaks secret scanning  
- ✅ TruffleHog secret detection
- ✅ TFSec Terraform security
- ✅ Security validation script
- ✅ Docker build

### Option 2: Run Individual Tests

**Test Spring Boot Build & Tests:**
```bash
make test-unit
make test-build
```

**Test Security Scanning:**
```bash
make test-security-gitleaks
make test-security-tfsec
make test-security-docker
```

**Test with Docker Compose:**
```bash
make test-docker-compose
```

**Test API Endpoints:**
```bash
make test-api
```

## 📋 Available Commands

| Command | Purpose |
|---------|---------|
| `make test-ci` | Run complete CI/CD pipeline (all checks) |
| `make test-unit` | Run Maven unit tests only |
| `make test-build` | Build Spring Boot app + Docker image |
| `make test-security-gitleaks` | Run Gitleaks secret pattern scanning |
| `make test-security-tfsec` | Run TFSec Terraform security scan |
| `make test-security-docker` | Run Trivy vulnerability scan on Docker image |
| `make test-docker-compose` | Run CI/CD pipeline with docker-compose |
| `make test-api` | Start app and test REST API |

## 🔧 Prerequisites

### Required
- **Docker** - For containerized testing
- **Java 17+** - For Spring Boot compilation
- **Maven** - For building the application

### Optional (for enhanced testing)
```bash
# Install security scanners
brew install gitleaks          # Secret pattern detection
brew install tfsec             # Terraform security
brew install trivy             # Vulnerability scanning
brew install trufflesecurity/trufflehog/trufflehog  # Secret detection
```

## 📊 Typical Workflow

### Before Pushing Changes

1. **Run complete CI/CD validation:**
   ```bash
   make test-ci
   ```
   Wait for all checks to pass with ✅.

2. **If failures occur, fix them locally:**
   - Fix the code
   - Re-run `make test-ci`

3. **Once all tests pass, push safely:**
   ```bash
   git push origin feature/first-model-library-with-spring
   ```

### Step-by-Step Testing

```bash
# Step 1: Run unit tests
make test-unit

# Step 2: Build application and Docker image
make test-build

# Step 3: Run security scans
make test-security-gitleaks
make test-security-tfsec
make test-security-docker

# Step 4: Test API locally
make test-api

# Only push if all passed!
git push origin feature/first-model-library-with-spring
```

## 🔐 Security Scanning Details

### Gitleaks
Detects hardcoded secrets using `.gitleaks.toml` configuration:
```bash
make test-security-gitleaks
```
- Scans for AWS credentials, API keys, private keys, etc.
- Uses custom allowlist for false positives

### TFSec
Terraform security scanning:
```bash
make test-security-tfsec
```
- Checks for misconfigurations (open security groups, unencrypted databases, etc.)
- Reports findings in pretty format

### Trivy
Vulnerability scanning for Docker images:
```bash
make test-security-docker
```
- Scans Docker image for known vulnerabilities
- Checks base images and dependencies

## 🐳 Docker Compose Pipeline

For complete isolation, run the full CI/CD pipeline in Docker:

```bash
make test-docker-compose
```

This spins up multiple containers:
- **java-builder**: Builds and tests Spring Boot app
- **gitleaks**: Runs secret pattern detection
- **trufflehog**: Additional secret detection
- **tfsec**: Terraform security scanning
- **trivy**: Vulnerability scanning
- **docker-builder**: Builds Docker image

All services use the same volume mounts, so results are visible locally.

## ✅ What Gets Tested

### Java Application
- ✅ Maven compilation
- ✅ Unit tests execution
- ✅ Test coverage
- ✅ JAR build
- ✅ Docker image build

### Infrastructure (Terraform)
- ✅ Format validation
- ✅ Security policy checks (tfsec)
- ✅ Configuration validation

### Secrets & Security
- ✅ Gitleaks: Pattern-based secret detection
- ✅ TruffleHog: Entropy-based secret detection
- ✅ Trivy: Vulnerability scanning
- ✅ .gitignore compliance

### Docker Image
- ✅ Build success
- ✅ Image layers
- ✅ Vulnerability scanning

## 🚨 Common Issues & Fixes

### Maven Tests Fail: Database Schema Not Found
**Problem:** `Table "BOOKS" not found`
**Solution:** Already fixed in `application.yml`:
```bash
make test-unit
```

### Gitleaks: Secret Pattern False Positives
**Issue:** Legitimate code flagged as secret
**Fix:** Update `.gitleaks.toml` allowlist
```toml
[allowlist]
paths = [
  ".*/security.*",
  ".*\.example"
]
```

### TFSec Fails on Missing Checkov Rules
**Problem:** TFSec doesn't recognize Checkov checks
**Solution:** Use native TFSec rules only (already configured)

### Docker Build Takes Too Long
**Optimization:** Use Docker layer caching
```bash
docker build --cache-from library-app:local .
```

## 📈 Performance Tips

- **First run**: 2-5 minutes (dependencies download)
- **Subsequent runs**: 30-60 seconds (cached)
- **To speed up**: Run only necessary checks (e.g., `make test-unit` instead of `make test-ci`)

## 🔄 Git Workflow Prevention

Local testing prevents these CI failures:
```
❌ Failed: mvn test
❌ Failed: secret leak detected
❌ Failed: tfsec findings
❌ Failed: Docker build failed
❌ Failed: API unreachable
```

Using local testing:
```
✅ Java build passed
✅ Security scans passed  
✅ Docker image built
✅ API verified
✅ Ready to push!
```

## 📚 Additional Resources

- **Maven**: https://maven.apache.org/guides/
- **Gitleaks**: https://github.com/gitleaks/gitleaks
- **TFSec**: https://github.com/aquasecurity/tfsec
- **Trivy**: https://github.com/aquasecurity/trivy
- **Docker Compose**: https://docs.docker.com/compose/

## 💡 Best Practices

1. ✅ **Always run `make test-ci` before pushing**
2. ✅ **Fix all issues locally** (faster than waiting for GitHub Actions)
3. ✅ **Run `make test-api`** to verify endpoints work
4. ✅ **Keep dependencies updated** (Maven, Docker, Java)
5. ✅ **Document** any new security exceptions needed

## 🎯 Success Criteria

Your changes are ready to push when:
- ✅ `make test-ci` completes with **all steps passing**
- ✅ No error messages in any step
- ✅ `make test-api` successfully queries the endpoint
- ✅ Docker image builds without warnings

---

**Questions?** Check GitHub Actions logs for detailed error messages after push.
