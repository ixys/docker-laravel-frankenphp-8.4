#!/bin/bash

# Quick Start Script for Docker Laravel FrankenPHP
# This script helps you get started quickly with the setup

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Docker Laravel FrankenPHP Quick Start        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print step
print_step() {
    echo -e "${GREEN}▶ $1${NC}"
}

# Function to print info
print_info() {
    echo -e "${YELLOW}  ℹ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}  ✗ $1${NC}"
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

print_step "Step 1: Validating setup..."
if [ -f "validate.sh" ]; then
    chmod +x validate.sh
    if ./validate.sh > /dev/null 2>&1; then
        print_info "Setup validation passed ✓"
    else
        print_error "Setup validation failed. Please check your configuration."
        exit 1
    fi
else
    print_info "Validation script not found, skipping..."
fi

echo ""
print_step "Step 2: Checking Laravel project..."

# Check if this is a Laravel project
if [ ! -f "composer.json" ]; then
    print_info "This doesn't appear to be a Laravel project."
    read -p "  Do you want to create a new Laravel 11 project? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_step "Creating new Laravel 11 project..."
        docker run --rm -v $(pwd):/app composer create-project laravel/laravel:^11.0 .
        print_info "Laravel 11 project created ✓"
    else
        print_info "Skipping Laravel project creation."
    fi
fi

echo ""
print_step "Step 3: Setting up environment..."

# Create .env if it doesn't exist
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_info ".env file created from .env.example ✓"
    else
        print_error ".env.example not found. Please create a .env file manually."
        exit 1
    fi
else
    print_info ".env file already exists ✓"
fi

# Generate app key if not set
if grep -q "APP_KEY=$" .env || grep -q "APP_KEY=\"\"" .env; then
    print_info "Generating application key..."
    docker run --rm -v $(pwd):/app -w /app composer:2 php artisan key:generate
    print_info "Application key generated ✓"
fi

echo ""
print_step "Step 4: Choose installation type..."
echo ""
echo "  1) Development (with hot reload, debug tools)"
echo "  2) Production (optimized, no dev tools)"
echo "  3) Build only (just build the image)"
echo ""
read -p "  Select option (1-3): " -n 1 -r OPTION
echo ""

case $OPTION in
    1)
        echo ""
        print_step "Starting development environment..."
        
        # Build development image
        print_info "Building development image..."
        docker build --target dev -t laravel-frankenphp:dev . || {
            print_error "Build failed. Please check the logs above."
            exit 1
        }
        
        # Start services
        print_info "Starting services..."
        docker-compose up -d
        
        echo ""
        print_step "Development environment ready! 🚀"
        echo ""
        echo -e "${YELLOW}Access your application:${NC}"
        echo "  • Application: http://localhost"
        echo "  • Health check: http://localhost/up"
        echo ""
        echo -e "${YELLOW}Useful commands:${NC}"
        echo "  • View logs: docker-compose logs -f app"
        echo "  • Run artisan: docker-compose exec app php artisan <command>"
        echo "  • Access shell: docker-compose exec app bash"
        echo "  • Stop services: docker-compose down"
        echo ""
        echo -e "${YELLOW}Debug tools (start with):${NC}"
        echo "  • docker-compose --profile debug up -d"
        echo "  • Redis Commander: http://localhost:8081"
        echo "  • Mailhog: http://localhost:8025"
        ;;
        
    2)
        echo ""
        print_step "Building production image..."
        
        # Build production image
        print_info "Building base runtime..."
        docker build --target base-runtime -t laravel-frankenphp:base . || {
            print_error "Base build failed. Please check the logs above."
            exit 1
        }
        
        print_info "Building production image..."
        docker build --target app -t laravel-frankenphp:latest . || {
            print_error "Production build failed. Please check the logs above."
            exit 1
        }
        
        echo ""
        print_step "Production image built successfully! 🎉"
        echo ""
        echo -e "${YELLOW}Run your production container:${NC}"
        echo "  docker run -d -p 80:80 \\"
        echo "    -e APP_ENV=production \\"
        echo "    -e APP_KEY=your-app-key \\"
        echo "    -e DB_HOST=your-db-host \\"
        echo "    --name laravel-app \\"
        echo "    laravel-frankenphp:latest"
        echo ""
        echo -e "${YELLOW}Or deploy to Kubernetes:${NC}"
        echo "  kubectl apply -f k8s/"
        ;;
        
    3)
        echo ""
        print_step "Building image..."
        
        # Build all stages
        print_info "Building base runtime..."
        docker build --target base-runtime -t laravel-frankenphp:base . || {
            print_error "Base build failed. Please check the logs above."
            exit 1
        }
        
        print_info "Building production image..."
        docker build --target app -t laravel-frankenphp:latest . || {
            print_error "Production build failed. Please check the logs above."
            exit 1
        }
        
        echo ""
        print_step "Image built successfully! 🎉"
        echo ""
        echo -e "${YELLOW}Available images:${NC}"
        docker images | grep laravel-frankenphp
        ;;
        
    *)
        print_error "Invalid option selected."
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  For more information:                        ║${NC}"
echo -e "${BLUE}║  • README.md - Usage guide                     ║${NC}"
echo -e "${BLUE}║  • DOCKER_OPTIMIZATION.md - Tech details       ║${NC}"
echo -e "${BLUE}║  • Makefile - Common commands                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""
