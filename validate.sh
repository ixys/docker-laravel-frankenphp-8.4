#!/bin/bash

# Validation script for Docker Laravel FrankenPHP setup
# This script validates the Dockerfile structure and configuration

set -e

echo "🔍 Validating Docker Setup..."

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0

# Function to print test results
test_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗${NC} $1"
        FAILED=$((FAILED + 1))
    fi
}

echo ""
echo "📋 Checking required files..."

# Check if Dockerfile exists
[ -f "Dockerfile" ]
test_result "Dockerfile exists"

# Check if docker-compose.yml exists
[ -f "docker-compose.yml" ]
test_result "docker-compose.yml exists"

# Check if Caddyfile exists
[ -f "Caddyfile" ]
test_result "Caddyfile exists"

# Check if .dockerignore exists
[ -f ".dockerignore" ]
test_result ".dockerignore exists"

echo ""
echo "🔧 Validating Dockerfile structure..."

# Check for base-runtime stage
grep -q "FROM dunglas/frankenphp:1-php8.4-bookworm AS base-runtime" Dockerfile
test_result "base-runtime stage defined"

# Check for dependencies stage
grep -q "FROM base-runtime AS dependencies" Dockerfile
test_result "dependencies stage defined"

# Check for frontend-builder stage
grep -q "FROM node:20-bookworm-slim AS frontend-builder" Dockerfile
test_result "frontend-builder stage defined"

# Check for final app stage
grep -q "FROM base-runtime AS app" Dockerfile
test_result "app stage defined"

# Check for dev stage
grep -q "FROM base-runtime AS dev" Dockerfile
test_result "dev stage defined"

echo ""
echo "🔍 Checking PHP extensions..."

# Check for essential PHP extensions
grep -q "pdo_mysql" Dockerfile
test_result "PDO MySQL extension configured"

grep -q "redis" Dockerfile
test_result "Redis extension configured"

grep -q "opcache" Dockerfile
test_result "OPcache extension configured"

echo ""
echo "⚙️ Validating OPcache configuration..."

# Check OPcache settings
grep -q "opcache.enable=1" Dockerfile
test_result "OPcache enabled"

grep -q "opcache.jit=tracing" Dockerfile
test_result "OPcache JIT configured"

grep -q "opcache.validate_timestamps=0" Dockerfile
test_result "OPcache validation disabled for production"

echo ""
echo "🔒 Checking security configurations..."

# Check for www-data user
grep -q "USER www-data" Dockerfile
test_result "Non-root user configured"

# Check for health check
grep -q "HEALTHCHECK" Dockerfile
test_result "Health check configured"

echo ""
echo "📦 Validating layer optimization..."

# Check that composer files are copied before application code
COMPOSER_LINE=$(grep -n "COPY.*composer.json" Dockerfile | head -1 | cut -d: -f1)
APP_COPY_LINE=$(grep -n "COPY.*\. /app" Dockerfile | head -1 | cut -d: -f1)

if [ -n "$COMPOSER_LINE" ] && [ -n "$APP_COPY_LINE" ] && [ "$COMPOSER_LINE" -lt "$APP_COPY_LINE" ]; then
    echo -e "${GREEN}✓${NC} Composer files copied before application code (optimal caching)"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗${NC} Layer ordering issue detected"
    FAILED=$((FAILED + 1))
fi

echo ""
echo "🐳 Validating docker-compose.yml..."

# Check for essential services
grep -q "app:" docker-compose.yml
test_result "App service defined"

grep -q "mysql:" docker-compose.yml
test_result "MySQL service defined"

grep -q "redis:" docker-compose.yml
test_result "Redis service defined"

# Check health checks in compose file
grep -q "healthcheck:" docker-compose.yml
test_result "Health checks defined"

echo ""
echo "🌐 Validating Caddyfile..."

# Check FrankenPHP workers configuration
grep -q "frankenphp" Caddyfile
test_result "FrankenPHP configuration present"

grep -q "num_workers" Caddyfile
test_result "Worker configuration present"

# Check health endpoint
grep -q "/up" Caddyfile
test_result "Health check endpoint configured"

echo ""
echo "📁 Checking Kubernetes manifests..."

# Check if k8s directory exists
[ -d "k8s" ]
test_result "k8s directory exists"

# Check for essential K8s files
[ -f "k8s/deployment.yaml" ]
test_result "Deployment manifest exists"

[ -f "k8s/secrets.yaml" ]
test_result "Secrets manifest exists"

[ -f "k8s/ingress.yaml" ]
test_result "Ingress manifest exists"

echo ""
echo "📚 Checking documentation..."

# Check documentation files
[ -f "README.md" ]
test_result "README.md exists"

[ -f "DOCKER_OPTIMIZATION.md" ]
test_result "DOCKER_OPTIMIZATION.md exists"

# Check if README has key sections
grep -q "## 🎯 Features" README.md
test_result "README has Features section"

grep -q "## 🏗️ Architecture" README.md
test_result "README has Architecture section"

echo ""
echo "═══════════════════════════════════════════════════"
echo -e "Test Results: ${GREEN}${PASSED} passed${NC}, ${RED}${FAILED} failed${NC}"
echo "═══════════════════════════════════════════════════"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✨ All validations passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some validations failed.${NC}"
    exit 1
fi
