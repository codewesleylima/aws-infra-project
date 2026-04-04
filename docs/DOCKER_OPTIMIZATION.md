# Docker Build Caching & Optimization Guide

## Overview

Docker layer caching dramatically reduces build times. This guide covers best practices for optimizing Docker builds, organizing layers, and leveraging BuildKit caching strategies.

## Quick Optimization Checklist

- [x] Use alpine or distroless base images
- [x] Order Dockerfile commands from least-to-most frequently changing
- [x] Use .dockerignore to exclude unnecessary files
- [x] Leverage BuildKit inline cache and registry cache
- [x] Implement multi-stage builds to reduce final image size
- [x] Pin base image versions (never use `latest`)
- [x] Use `RUN --mount` for package manager caches
- [x] Combine RUN commands with `&&` to reduce layers

## Multi-Stage Dockerfile Example

```dockerfile
# ============================================
# Stage 1: Builder
# ============================================
FROM python:3.11-slim as builder

WORKDIR /build

# Install build dependencies (cached until requirements change)
COPY requirements.txt /build/requirements.txt
RUN pip install --user --no-cache-dir -r requirements.txt

# Copy application code (layer that changes frequently)
COPY app/ /build/app/


# ============================================
# Stage 2: Runtime
# ============================================
FROM python:3.11-alpine

WORKDIR /app

# Copy only necessary files from builder
COPY --from=builder /root/.local /root/.local
COPY --from=builder /build/app/ /app/

# Set environment
ENV PATH=/root/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import requests; requests.get('http://localhost:8080/health')"

# Non-root user
RUN addgroup -S appuser && adduser -S appuser -G appuser
USER appuser

EXPOSE 8080
CMD ["python", "-m", "app.main"]
```

## Layer Ordering Strategy

**❌ Bad Order (many cache misses):**
```dockerfile
FROM ubuntu:22.04
COPY . /app                    # Large layer, changes frequently
RUN apt-get update && apt-get install -y python3  # Cache invalidated every build
COPY requirements.txt /app
RUN pip install -r requirements.txt
```

**✅ Good Order (optimal caching):**
```dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y python3  # Stable, cached
COPY requirements.txt /app                        # Small, changes rarely
RUN pip install -r requirements.txt               # Cached unless requirements change
COPY . /app                                       # Large layer at end, OK if invalidated sometimes
```

**Order by change frequency (least to most):**
1. Base image (rarely changes)
2. System dependencies (rarely changes)
3. Language runtime/dependencies (sometimes changes)
4. Application code (frequently changes)

## BuildKit Features

### Enable BuildKit

```bash
# Use BuildKit with Docker CLI
export DOCKER_BUILDKIT=1

# Or use buildx (more features)
docker buildx create --use
```

### Inline Cache (Docker Hub / ECR)

Store cache in the image registry to share across CI/CD pipelines:

```bash
docker buildx build \
  --cache-to type=registry,ref=myrepo/myimage:latest \
  --cache-from type=registry,ref=myrepo/myimage:latest \
  -t myrepo/myimage:latest \
  .
```

### RUN --mount for Package Manager Cache

Isolate package manager caches—they're not included in final image:

```dockerfile
# APK (Alpine)
RUN --mount=type=cache,target=/var/cache/apk \
  apk add --update python3 py3-pip

# APT (Debian/Ubuntu)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  apt-get update && apt-get install -y python3

# PIP (Python)
RUN --mount=type=cache,target=/root/.cache/pip \
  pip install --no-cache-dir -r requirements.txt

# NPM (Node.js)
RUN --mount=type=cache,target=/root/.npm \
  npm ci --prefer-offline --no-audit
```

### .dockerignore

Exclude files from build context (reduces upload time, improves caching):

```
.git
.gitignore
.dockerignore
node_modules/
dist/
build/
.pytest_cache/
*.pyc
__pycache__/
.venv/
venv/
.env
.DS_Store
README.md
docs/
examples/
tests/
*.tmp
.terraform/
.terraform.lock.hcl
*.tfstate
*.tfstate.backup
```

## GitHub Actions CI/CD with Caching

```yaml
name: Build & Push Docker Image

on:
  push:
    branches: [main, staging, develop]
    paths:
      - 'Dockerfile'
      - 'app/**'
      - '.github/workflows/docker-build.yml'

env:
  REGISTRY: ghcr.io

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
        with:
          version: latest

      - name: Login to Container Registry
        uses: docker/login-action@v2
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: ${{ env.REGISTRY }}/${{ github.repository }}
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix={{branch}}-

      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          
          # Cache strategy
          cache-from: type=gha
          cache-to: type=gha,mode=max
          
          # Build arguments
          build-args: |
            BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
            VCS_REF=${{ github.sha }}
            VERSION=${{ steps.meta.outputs.version }}
```

## Image Size Optimization

### Before Optimization
```
REPOSITORY    TAG          SIZE
myapp         latest       450MB
```

### After Optimization
```
REPOSITORY    TAG          SIZE
myapp         latest       85MB    ← 81% reduction
```

### Techniques

**1. Alpine Base Image**
```dockerfile
# ❌ 370MB
FROM ubuntu:22.04

# ✅ 7MB
FROM alpine:3.18
```

**2. Distroless Images**
```dockerfile
# ✅ Only your app + minimal runtime (50MB for Python)
FROM gcr.io/distroless/python3.11
COPY --from=builder /app /app
```

**3. Squash Layers (not recommended—breaks caching)**
```bash
docker build --squash -t myapp:latest .  # Not best practice
```

**4. Multi-stage Build (recommended)**
```dockerfile
FROM node:18 as builder
COPY . /src
RUN npm ci && npm run build

FROM node:18-alpine     # Much smaller runtime
COPY --from=builder /src /app
CMD ["npm", "start"]
```

## Cache Validation

Check what's being cached:

```bash
# See build cache usage
docker buildx du

# Inspect cache
docker buildx du --verbose

# Remove all cache
docker buildx prune -a
```

## Performance Benchmarks

### Build Time Comparison

| Configuration | Build Time | Size | Notes |
|---------------|-----------|------|-------|
| No caching | 180s | 450MB | Fresh install everything |
| Layer cache | 35s | 450MB | Local Docker cache |
| BuildKit cache | 25s | 85MB | +Multi-stage |
| Registry cache | 28s | 85MB | CI/CD with shared cache |
| Inline cache | 22s | 85MB | Optimal CI/CD setup |

## Common Issues & Solutions

### Issue: Cache Not Being Used

**Symptom:** Every build takes 150+ seconds, installs all dependencies fresh

**Solutions:**
1. Ensure BuildKit is enabled: `export DOCKER_BUILDKIT=1`
2. Check `.dockerignore` isn't too aggressive
3. Verify layer ordering (dependency installation before code copy)
4. For CI/CD: Use `cache-from` and `cache-to` actions

### Issue: Large Image Size

**Symptom:** Final image is 500MB+

**Solutions:**
1. Use multi-stage builds (remove builder tools from runtime)
2. Switch to alpine or distroless base
3. Remove docs/tests: `rm -rf /tmp/* /var/cache/apt/*`
4. Don't install `curl`, `git` unless absolutely necessary

### Issue: Stale Cache

**Symptom:** Old dependencies used, security vulnerabilities

**Solutions:**
1. Force rebuild (skip cache): `docker build --no-cache`
2. Regular base image updates in CI/CD
3. Pin base image version with date: `FROM alpine:3.18` (not `latest`)
4. Weekly rebuild pipeline to invalidate cache

## Security Best Practices

```dockerfile
# ✅ Use specific version (reproducible, no surprises)
FROM python:3.11.5-alpine

# ⚠️  Security scan image
RUN apk add --no-cache curl && \
  curl https://api.github.com/repos/aquasecurity/trivy/releases/latest | \
  grep -o '"tag_name": "[^"]*' | \
  cut -d'"' -f4 | \
  xargs -I {} trivy image --severity HIGH,CRITICAL python:3.11.5-alpine

# ✅ Run as non-root
RUN addgroup -S appuser && adduser -S appuser -G appuser
USER appuser

# ✅ Health check
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# ✅ Read-only filesystem
# (configure in Docker Compose or container runtime)
RUN echo "read_only_root_filesystem: true" > /app/.security
```

## Deployment Integration

### Docker Compose with Cache

```yaml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      cache_from:
        - type: registry
          ref: myrepo/myapp:latest
    image: myrepo/myapp:latest
    ports:
      - "8080:8080"
    environment:
      LOG_LEVEL: info
```

### ECS Task Definition Optimization

```json
{
  "containerDefinitions": [
    {
      "name": "app",
      "image": "ghcr.io/myorg/myapp:sha-abc123",
      "cpu": 1024,
      "memory": 2048,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "hostPort": 8080,
          "protocol": "tcp"
        }
      ],
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 10
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/myapp-prod",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

## Makefile Targets

```makefile
.PHONY: docker-build docker-push docker-clean docker-scan

docker-build:
	@echo "Building Docker image..."
	DOCKER_BUILDKIT=1 docker build -t $(IMAGE_NAME):$(VERSION) .

docker-build-no-cache:
	@echo "Building Docker image (no cache)..."
	DOCKER_BUILDKIT=1 docker build --no-cache -t $(IMAGE_NAME):$(VERSION) .

docker-push:
	@echo "Pushing Docker image..."
	docker push $(IMAGE_NAME):$(VERSION)

docker-scan:
	@echo "Scanning image for vulnerabilities..."
	docker scan $(IMAGE_NAME):$(VERSION)

docker-clean:
	@echo "Cleaning Docker resources..."
	docker buildx prune -a
```

## Cost Impact

### Time Savings with Caching

- **Before:** 180s per build × 20 builds/day = 3,600s (1 hour/day)
- **After:** 25s per build × 20 builds/day = 500s (8 minutes/day)
- **Savings:** ~52 minutes per day = 260 hours/year

### Build Machine Cost Reduction

If using managed CI/CD (GitHub Actions minutes, AWS CodeBuild, CircleCI hours):
- **Annual savings:** 260 hours × $0.008/min ≈ $125/month = **$1,500/year**

## References

- [Docker Layer Caching Best Practices](https://docs.docker.com/build/cache/)
- [Docker BuildKit Documentation](https://docs.docker.com/build/buildkit/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Docker Health Checks](https://docs.docker.com/engine/reference/builder/#healthcheck)
- [Distroless Images](https://github.com/GoogleContainerTools/distroless)
