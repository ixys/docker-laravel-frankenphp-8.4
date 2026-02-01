# Exemples d'utilisation des images Docker

Ce fichier contient des exemples pratiques d'utilisation des images Docker Laravel FrankenPHP.

## Docker Compose - Production

```yaml
version: '3.8'

services:
  app:
    # Image full depuis GHCR
    image: ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:latest
    
    # Ou image slim pour production minimale
    # image: ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:slim
    
    # Ou depuis Scaleway
    # image: rg.fr-par.scw.cloud/registry-ixys-dev/docker-laravel-frankenphp-8.4:latest
    
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    environment:
      - APP_ENV=production
      - APP_DEBUG=false
      - APP_KEY=${APP_KEY}
      - DB_HOST=mysql
      - DB_DATABASE=${DB_DATABASE}
      - DB_USERNAME=${DB_USERNAME}
      - DB_PASSWORD=${DB_PASSWORD}
      - REDIS_HOST=redis
      - CACHE_DRIVER=redis
      - SESSION_DRIVER=redis
      - FRANKENPHP_NUM_WORKERS=4
    depends_on:
      - mysql
      - redis
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/up"]
      interval: 30s
      timeout: 3s
      retries: 3

  mysql:
    image: mysql:8.0
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: ${DB_DATABASE}
      MYSQL_USER: ${DB_USERNAME}
      MYSQL_PASSWORD: ${DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    volumes:
      - redis_data:/data

volumes:
  mysql_data:
  redis_data:
```

## Kubernetes - Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: laravel-app
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: laravel
  template:
    metadata:
      labels:
        app: laravel
    spec:
      containers:
      - name: app
        # Version pinned pour production
        image: ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:v1.2.3
        
        # Ou slim pour économiser de la bande passante
        # image: ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:v1.2.3-slim
        
        ports:
        - containerPort: 80
          name: http
        - containerPort: 443
          name: https
        
        env:
        - name: APP_ENV
          value: "production"
        - name: APP_KEY
          valueFrom:
            secretKeyRef:
              name: laravel-secrets
              key: app-key
        - name: DB_HOST
          value: "mysql-service"
        - name: REDIS_HOST
          value: "redis-service"
        - name: FRANKENPHP_NUM_WORKERS
          value: "4"
        
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        
        livenessProbe:
          httpGet:
            path: /up
            port: 80
          initialDelaySeconds: 40
          periodSeconds: 30
        
        readinessProbe:
          httpGet:
            path: /up
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
      
      imagePullSecrets:
      - name: ghcr-credentials
---
apiVersion: v1
kind: Service
metadata:
  name: laravel-service
  namespace: production
spec:
  selector:
    app: laravel
  ports:
  - port: 80
    targetPort: 80
    name: http
  - port: 443
    targetPort: 443
    name: https
  type: ClusterIP
```

## Kubernetes - ImagePullSecret

### Pour GHCR

```bash
# Créer le secret avec votre token GitHub
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username=your-github-username \
  --docker-password=your-github-token \
  --docker-email=your-email@example.com \
  -n production
```

### Pour Scaleway

```bash
# Créer le secret avec votre token Scaleway
kubectl create secret docker-registry scw-credentials \
  --docker-server=rg.fr-par.scw.cloud \
  --docker-username=nologin \
  --docker-password=your-scw-token \
  --docker-email=your-email@example.com \
  -n production
```

## Docker Run - Local Testing

```bash
# Test avec image full
docker run -d \
  --name laravel-test \
  -p 8080:80 \
  -e APP_ENV=local \
  -e APP_KEY=base64:your-key-here \
  ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:latest

# Vérifier les logs
docker logs -f laravel-test

# Tester l'application
curl http://localhost:8080/up

# Nettoyer
docker rm -f laravel-test
```

## Docker Run - Production Simple

```bash
# Démarrer avec image slim et variables d'environnement
docker run -d \
  --name laravel-prod \
  --restart unless-stopped \
  -p 80:80 \
  -p 443:443 \
  -e APP_ENV=production \
  -e APP_DEBUG=false \
  -e APP_KEY=${APP_KEY} \
  -e DB_HOST=your-db-host \
  -e DB_DATABASE=laravel \
  -e DB_USERNAME=laravel \
  -e DB_PASSWORD=${DB_PASSWORD} \
  -e REDIS_HOST=your-redis-host \
  -e CACHE_DRIVER=redis \
  -e SESSION_DRIVER=redis \
  -e FRANKENPHP_NUM_WORKERS=4 \
  ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:slim

# Health check
curl http://localhost/up

# Logs en temps réel
docker logs -f laravel-prod
```

## AWS ECS Task Definition

```json
{
  "family": "laravel-frankenphp",
  "containerDefinitions": [
    {
      "name": "app",
      "image": "ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:v1.2.3",
      "cpu": 512,
      "memory": 1024,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "APP_ENV",
          "value": "production"
        },
        {
          "name": "FRANKENPHP_NUM_WORKERS",
          "value": "4"
        }
      ],
      "secrets": [
        {
          "name": "APP_KEY",
          "valueFrom": "arn:aws:secretsmanager:region:account:secret:app-key"
        }
      ],
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost/up || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/laravel-frankenphp",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "app"
        }
      }
    }
  ],
  "requiresCompatibilities": ["FARGATE"],
  "networkMode": "awsvpc",
  "cpu": "512",
  "memory": "1024"
}
```

## GitLab CI/CD

```yaml
stages:
  - deploy

deploy-production:
  stage: deploy
  image: alpine:latest
  before_script:
    - apk add --no-cache curl
  script:
    # Pull depuis GHCR ou Scaleway
    - docker pull ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:latest
    
    # Déployer (exemple avec docker-compose)
    - docker-compose -f docker-compose.prod.yml up -d
    
    # Attendre que l'application soit prête
    - sleep 10
    
    # Vérifier health check
    - curl -f http://localhost/up
  only:
    - main
  environment:
    name: production
```

## Terraform - AWS ECS

```hcl
resource "aws_ecs_task_definition" "laravel" {
  family                   = "laravel-frankenphp"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "app"
      image = "ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:v1.2.3"
      
      essential = true
      
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "APP_ENV"
          value = "production"
        },
        {
          name  = "FRANKENPHP_NUM_WORKERS"
          value = "4"
        }
      ]
      
      secrets = [
        {
          name      = "APP_KEY"
          valueFrom = aws_secretsmanager_secret.app_key.arn
        }
      ]
      
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost/up || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.laravel.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])
}
```

## Ansible Playbook

```yaml
---
- name: Deploy Laravel with FrankenPHP
  hosts: webservers
  become: yes
  
  vars:
    image_name: "ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4"
    image_tag: "v1.2.3"
    container_name: "laravel-app"
  
  tasks:
    - name: Pull Docker image
      docker_image:
        name: "{{ image_name }}"
        tag: "{{ image_tag }}"
        source: pull
    
    - name: Stop existing container
      docker_container:
        name: "{{ container_name }}"
        state: absent
      ignore_errors: yes
    
    - name: Start new container
      docker_container:
        name: "{{ container_name }}"
        image: "{{ image_name }}:{{ image_tag }}"
        state: started
        restart_policy: unless-stopped
        ports:
          - "80:80"
          - "443:443"
        env:
          APP_ENV: "production"
          APP_KEY: "{{ vault_app_key }}"
          FRANKENPHP_NUM_WORKERS: "4"
        healthcheck:
          test: ["CMD", "curl", "-f", "http://localhost/up"]
          interval: 30s
          timeout: 3s
          retries: 3
    
    - name: Wait for application to be ready
      uri:
        url: "http://localhost/up"
        status_code: 200
      register: result
      until: result.status == 200
      retries: 10
      delay: 5
```

## Makefile - Déploiement Simplifié

```makefile
.PHONY: pull-full pull-slim deploy-full deploy-slim health

# Variables
REGISTRY ?= ghcr.io/jsimoncini
IMAGE_NAME ?= docker-laravel-frankenphp-8.4
TAG ?= latest

pull-full:
	docker pull $(REGISTRY)/$(IMAGE_NAME):$(TAG)

pull-slim:
	docker pull $(REGISTRY)/$(IMAGE_NAME):$(TAG)-slim

deploy-full: pull-full
	docker-compose -f docker-compose.prod.yml up -d
	@echo "Waiting for application..."
	@sleep 10
	@curl -f http://localhost/up && echo "✓ Health check passed"

deploy-slim: pull-slim
	docker-compose -f docker-compose.prod-slim.yml up -d
	@echo "Waiting for application..."
	@sleep 10
	@curl -f http://localhost/up && echo "✓ Health check passed"

health:
	@curl -f http://localhost/up && echo "✓ Application is healthy" || echo "✗ Application is unhealthy"

logs:
	docker-compose -f docker-compose.prod.yml logs -f app

stop:
	docker-compose -f docker-compose.prod.yml down
```

## Notes importantes

### Sélection de l'architecture

Les images supportent multi-arch (`linux/amd64` et `linux/arm64`). Docker sélectionne automatiquement la bonne architecture :

```bash
# Sur machine Intel/AMD
docker pull ghcr.io/.../app:latest
# → Télécharge linux/amd64

# Sur Apple Silicon (M1/M2/M3)
docker pull ghcr.io/.../app:latest
# → Télécharge linux/arm64

# Sur AWS Graviton
docker pull ghcr.io/.../app:latest
# → Télécharge linux/arm64
```

### Variables d'environnement essentielles

Minimum requis pour production :
- `APP_KEY` - Clé de chiffrement Laravel
- `APP_ENV=production`
- `APP_DEBUG=false`
- `DB_HOST`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`
- `REDIS_HOST` (si cache Redis)
- `FRANKENPHP_NUM_WORKERS` (nombre de workers, défaut: 4)

### Health checks

L'endpoint `/up` retourne :
- `200 OK` si l'application est healthy
- `500` ou timeout si problème

Utilisez cet endpoint pour :
- Kubernetes liveness/readiness probes
- Load balancer health checks
- Monitoring externe
- Déploiements progressifs
