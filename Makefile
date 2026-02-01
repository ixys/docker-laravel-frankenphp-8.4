.PHONY: help build build-dev build-base push dev up down logs shell composer artisan test clean

# Variables
IMAGE_NAME ?= laravel-frankenphp
IMAGE_TAG ?= latest
REGISTRY ?= ghcr.io/your-org

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build production image
	docker build --target app -t $(IMAGE_NAME):$(IMAGE_TAG) .

build-dev: ## Build development image
	docker build --target dev -t $(IMAGE_NAME):dev .

build-base: ## Build base runtime image (for CI/CD caching)
	docker build --target base-runtime -t $(IMAGE_NAME):base .

build-all: build-base build ## Build all images

push: ## Push images to registry
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	docker push $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

push-base: ## Push base runtime to registry
	docker tag $(IMAGE_NAME):base $(REGISTRY)/$(IMAGE_NAME):base
	docker push $(REGISTRY)/$(IMAGE_NAME):base

dev: ## Start development environment
	docker-compose up -d

up: dev ## Alias for dev

down: ## Stop development environment
	docker-compose down

restart: down up ## Restart development environment

logs: ## View application logs
	docker-compose logs -f app

logs-all: ## View all container logs
	docker-compose logs -f

shell: ## Open shell in application container
	docker-compose exec app /bin/bash

mysql: ## Open MySQL shell
	docker-compose exec mysql mysql -u laravel -p laravel

redis: ## Open Redis CLI
	docker-compose exec redis redis-cli

composer: ## Run composer commands (e.g., make composer CMD="require vendor/package")
	docker-compose exec app composer $(CMD)

artisan: ## Run artisan commands (e.g., make artisan CMD="migrate")
	docker-compose exec app php artisan $(CMD)

migrate: ## Run database migrations
	docker-compose exec app php artisan migrate

migrate-fresh: ## Fresh migration with seeding
	docker-compose exec app php artisan migrate:fresh --seed

test: ## Run tests
	docker-compose exec app php artisan test

test-coverage: ## Run tests with coverage
	docker-compose exec app php artisan test --coverage

optimize: ## Optimize Laravel for production
	docker-compose exec app php artisan config:cache
	docker-compose exec app php artisan route:cache
	docker-compose exec app php artisan view:cache

clear-cache: ## Clear all caches
	docker-compose exec app php artisan optimize:clear

npm: ## Run npm commands (e.g., make npm CMD="install")
	docker-compose exec app npm $(CMD)

npm-dev: ## Run npm dev server
	docker-compose exec app npm run dev

npm-build: ## Build production assets
	docker-compose exec app npm run build

clean: ## Clean up Docker resources
	docker-compose down -v
	docker system prune -f

clean-all: ## Clean up all Docker resources including images
	docker-compose down -v --rmi all
	docker system prune -af

ps: ## Show running containers
	docker-compose ps

stats: ## Show container resource usage
	docker stats

health: ## Check application health
	@curl -f http://localhost/up && echo "✓ Health check passed" || echo "✗ Health check failed"

# Kubernetes targets
k8s-deploy: ## Deploy to Kubernetes
	kubectl apply -f k8s/

k8s-delete: ## Delete from Kubernetes
	kubectl delete -f k8s/

k8s-logs: ## View Kubernetes logs
	kubectl logs -l app=laravel -f

k8s-shell: ## Open shell in Kubernetes pod
	kubectl exec -it deployment/laravel-app -- /bin/bash

# CI/CD helpers
ci-build: ## Build images for CI/CD with cache
	docker buildx build \
		--target base-runtime \
		--cache-from type=registry,ref=$(REGISTRY)/$(IMAGE_NAME):base \
		--cache-to type=registry,ref=$(REGISTRY)/$(IMAGE_NAME):base,mode=max \
		-t $(REGISTRY)/$(IMAGE_NAME):base \
		.
	docker buildx build \
		--target app \
		--cache-from type=registry,ref=$(REGISTRY)/$(IMAGE_NAME):base \
		--cache-from type=registry,ref=$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) \
		--cache-to type=registry,ref=$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG),mode=max \
		-t $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) \
		--push \
		.

ci-test: ## Run CI tests
	docker-compose -f docker-compose.yml -f docker-compose.ci.yml run --rm app php artisan test
