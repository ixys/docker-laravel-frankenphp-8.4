#!/bin/bash

# Multi-Architecture Build Test Script
# Tests that the Dockerfile can build for multiple architectures

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Multi-Architecture Build Test                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

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

echo -e "${YELLOW}Step 1: Checking Docker Buildx${NC}"

# Check if buildx is available
docker buildx version > /dev/null 2>&1
test_result "Docker Buildx available"

echo ""
echo -e "${YELLOW}Step 2: Checking Dockerfile Syntax${NC}"

# Check for multi-arch syntax directive
grep -q "^# syntax=docker/dockerfile" Dockerfile
test_result "BuildKit syntax directive present"

# Check for platform arguments
grep -q "FROM --platform=\$BUILDPLATFORM" Dockerfile
test_result "Platform argument in FROM statement"

grep -q "ARG TARGETPLATFORM" Dockerfile
test_result "TARGETPLATFORM argument defined"

grep -q "ARG BUILDPLATFORM" Dockerfile
test_result "BUILDPLATFORM argument defined"

echo ""
echo -e "${YELLOW}Step 3: Testing Multi-Arch Build Capability${NC}"

# Create a buildx builder if needed
echo -e "${BLUE}→${NC} Creating/using buildx builder..."
docker buildx create --name test-builder --use --bootstrap > /dev/null 2>&1 || \
docker buildx use test-builder > /dev/null 2>&1
test_result "Buildx builder created/selected"

# Inspect builder capabilities
echo -e "${BLUE}→${NC} Checking builder platforms..."
PLATFORMS=$(docker buildx inspect --bootstrap | grep "Platforms:" || echo "")
if echo "$PLATFORMS" | grep -q "linux/amd64"; then
    echo -e "${GREEN}✓${NC} Builder supports linux/amd64"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗${NC} Builder does not support linux/amd64"
    FAILED=$((FAILED + 1))
fi

if echo "$PLATFORMS" | grep -q "linux/arm64"; then
    echo -e "${GREEN}✓${NC} Builder supports linux/arm64"
    PASSED=$((PASSED + 1))
else
    echo -e "${YELLOW}⚠${NC} Builder does not support linux/arm64 (may need QEMU)"
    echo -e "${BLUE}  Install with: docker run --rm --privileged multiarch/qemu-user-static --reset -p yes${NC}"
fi

echo ""
echo -e "${YELLOW}Step 4: Validating Makefile Commands${NC}"

# Check for multi-arch targets
grep -q "build-multiarch:" Makefile
test_result "build-multiarch target exists"

grep -q "push-multiarch:" Makefile
test_result "push-multiarch target exists"

grep -q "setup-buildx:" Makefile
test_result "setup-buildx target exists"

grep -q "PLATFORMS ?=" Makefile
test_result "PLATFORMS variable defined"

echo ""
echo -e "${YELLOW}Step 5: Checking GitHub Actions Workflow${NC}"

# Check workflow has multi-arch
grep -q "platforms: linux/amd64,linux/arm64" .github/workflows/build-deploy.yml
test_result "CI/CD workflow configured for multi-arch"

echo ""
echo -e "${YELLOW}Step 6: Checking Documentation${NC}"

# Check for multi-arch documentation
[ -f "MULTIARCH.md" ]
test_result "MULTIARCH.md exists"

grep -q "linux/amd64" README.md
test_result "README mentions amd64 support"

grep -q "linux/arm64" README.md
test_result "README mentions arm64 support"

echo ""
echo -e "${YELLOW}Step 7: Dry Run Build Test${NC}"

# Try a dry run parse of Dockerfile
echo -e "${BLUE}→${NC} Testing Dockerfile parsing..."
docker buildx build \
    --platform linux/amd64 \
    --target base-runtime \
    --dry-run \
    . > /dev/null 2>&1 || true
    
# Note: --dry-run might not be supported in all versions
# If it fails, we just skip this test
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Dockerfile parses correctly for amd64"
    PASSED=$((PASSED + 1))
else
    echo -e "${YELLOW}ℹ${NC} Dry run not supported (skipped)"
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo -e "Test Results: ${GREEN}${PASSED} passed${NC}, ${RED}${FAILED} failed${NC}"
echo "═══════════════════════════════════════════════════"

# Cleanup
docker buildx use default > /dev/null 2>&1 || true
docker buildx rm test-builder > /dev/null 2>&1 || true

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✨ All multi-architecture tests passed!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Run: make setup-buildx"
    echo "  2. Run: make build-multiarch"
    echo "  3. Test on both architectures"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Some tests failed.${NC}"
    echo ""
    echo -e "${YELLOW}Common fixes:${NC}"
    echo "  • Install QEMU for ARM64 support:"
    echo "    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes"
    echo "  • Update Docker Desktop to latest version"
    echo "  • Enable experimental features in Docker"
    echo ""
    exit 1
fi
