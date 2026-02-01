# Comparaison des Workflows GitHub Actions

Ce document compare les deux workflows GitHub Actions disponibles dans ce projet.

## Vue d'ensemble

| Aspect | build-deploy.yml | docker-build.yml |
|--------|------------------|------------------|
| **Type** | Workflow original | Nouveau workflow dual-registry |
| **Registre** | GHCR uniquement | Scaleway + GHCR |
| **Images** | Full (app) | Full + Slim |
| **Déploiement** | Inclus (K8S) | Build/Push uniquement |
| **Scan sécurité** | ✅ Trivy | ❌ Non inclus |
| **Multi-arch** | ✅ Oui | ✅ Oui |

## build-deploy.yml (Original)

### Caractéristiques

✅ **Workflow complet avec déploiement**
- Build multi-arch (amd64, arm64)
- Push vers GHCR uniquement
- Scan de sécurité Trivy
- Déploiement automatique vers staging (develop)
- Déploiement automatique vers production (main)
- Exécution des migrations
- Cache optimisé

### Structure

```
jobs:
  1. build
     - Build base-runtime
     - Build app
     - Push vers GHCR
  
  2. security-scan
     - Scan Trivy
     - Upload SARIF
  
  3. deploy-staging (si develop)
     - Deploy vers K8S staging
     - Migrations
  
  4. deploy-production (si main)
     - Deploy vers K8S production
     - Migrations
     - Cache clearing
```

### Déclencheurs

```yaml
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]
```

### Cas d'usage recommandé

✅ **Utilisez build-deploy.yml si :**
- Vous déployez sur Kubernetes
- Vous voulez un workflow tout-en-un (build + scan + deploy)
- Vous utilisez uniquement GHCR
- Vous voulez des déploiements automatiques
- Vous avez besoin de scans de sécurité Trivy

## docker-build.yml (Nouveau)

### Caractéristiques

✅ **Build et push vers deux registres**
- Build multi-arch (amd64, arm64)
- Push vers Scaleway ET GHCR
- Variantes full + slim
- Tests automatisés (health checks)
- Push conditionnel (main/develop/release)
- Support des branches feature (build sans push)
- Tagging sémantique avancé

### Structure

```
jobs:
  1. build-and-push
     - Build full image (multi-arch)
     - Build slim image (multi-arch)
     - Tests sur full (PHP, extensions, health)
     - Tests sur slim (PHP, health)
     - Push vers Scaleway (si conditions)
     - Push vers GHCR (si conditions)
```

### Déclencheurs

```yaml
on:
  push:
    branches: [main, develop, feature/*]
  pull_request:
    branches: [main, develop]
  release:
    types: [published]
  workflow_dispatch:
```

### Cas d'usage recommandé

✅ **Utilisez docker-build.yml si :**
- Vous voulez deux registres (redondance)
- Vous avez besoin d'une image slim
- Vous voulez tester les PRs et features sans push
- Vous gérez le déploiement séparément (ArgoCD, Flux, etc.)
- Vous utilisez Scaleway Container Registry
- Vous voulez un tagging plus flexible

## Comparaison détaillée

### Registres

| Workflow | GHCR | Scaleway | Autre |
|----------|------|----------|-------|
| build-deploy.yml | ✅ | ❌ | Facile à adapter |
| docker-build.yml | ✅ | ✅ | Facile à ajouter |

### Variantes d'images

| Workflow | Full | Slim | Dev |
|----------|------|------|-----|
| build-deploy.yml | ✅ (app target) | ❌ | Possible |
| docker-build.yml | ✅ (app target) | ✅ (slim target) | Possible |

### Tests

| Test | build-deploy.yml | docker-build.yml |
|------|------------------|------------------|
| PHP version | ❌ | ✅ |
| Extensions PHP | ❌ | ✅ |
| FrankenPHP binary | ❌ | ✅ |
| Health check /up | ❌ | ✅ |
| Container liveness | ❌ | ✅ |
| Scan sécurité | ✅ Trivy | ❌ |

### Déploiement

| Aspect | build-deploy.yml | docker-build.yml |
|--------|------------------|------------------|
| Deploy K8S | ✅ Automatique | ❌ Externe |
| Migrations | ✅ Auto | ❌ Externe |
| Cache clearing | ✅ Auto | ❌ Externe |
| Staging | ✅ | ❌ |
| Production | ✅ | ❌ |

### Tagging

**build-deploy.yml:**
```
ghcr.io/{owner}/{repo}:main
ghcr.io/{owner}/{repo}:develop
ghcr.io/{owner}/{repo}:{sha}
ghcr.io/{owner}/{repo}:latest
ghcr.io/{owner}/{repo}:{version}
```

**docker-build.yml:**
```
# Scaleway
rg.fr-par.scw.cloud/registry-ixys-dev/{repo}:{branch}
rg.fr-par.scw.cloud/registry-ixys-dev/{repo}:{branch}_{sha}
rg.fr-par.scw.cloud/registry-ixys-dev/{repo}:latest
rg.fr-par.scw.cloud/registry-ixys-dev/{repo}:{branch}-slim
rg.fr-par.scw.cloud/registry-ixys-dev/{repo}:{branch}_{sha}-slim
rg.fr-par.scw.cloud/registry-ixys-dev/{repo}:slim
rg.fr-par.scw.cloud/registry-ixys-dev/{repo}:{version}
rg.fr-par.scw.cloud/registry-ixys-dev/{repo}:{version}-slim

# GHCR (identique mais sur ghcr.io)
```

### Push conditionnel

**build-deploy.yml:**
- ✅ Push sur push vers main/develop
- ❌ Pas de push sur PR

**docker-build.yml:**
- ✅ Push sur push vers main/develop
- ✅ Push sur release published
- ❌ Pas de push sur PR
- ❌ Pas de push sur feature branches

### Durée d'exécution

**build-deploy.yml:**
- Build seul: ~8-10 min
- Build + deploy staging: ~12-15 min
- Build + deploy prod: ~15-20 min

**docker-build.yml:**
- Build + tests: ~12-15 min (deux images)
- Build + tests + push: ~15-18 min

## Quelle workflow choisir ?

### Scénario 1: Projet simple avec K8S

**Recommandation: build-deploy.yml**

✅ Avantages:
- Tout-en-un
- Déploiement automatique
- Scan de sécurité inclus
- Plus simple à maintenir

❌ Inconvénients:
- Un seul registre
- Pas de variante slim
- Moins flexible

### Scénario 2: Production avec haute disponibilité

**Recommandation: docker-build.yml**

✅ Avantages:
- Deux registres (redondance)
- Image slim pour économies
- Tests plus complets
- Tagging flexible

❌ Inconvénients:
- Déploiement séparé
- Plus complexe
- Requiert ArgoCD/Flux

### Scénario 3: Développement avec feature branches

**Recommandation: docker-build.yml**

✅ Avantages:
- Build sur toutes les branches
- Test des PRs
- Pas de push inutile
- Feedback rapide

❌ Inconvénients:
- Pas de déploiement auto

### Scénario 4: Maximum sécurité

**Recommandation: build-deploy.yml**

✅ Avantages:
- Scan Trivy automatique
- Upload vers GitHub Security
- Alertes de vulnérabilités

Ou combinez les deux:
- docker-build.yml pour le build
- Ajoutez Trivy séparément

## Peut-on utiliser les deux ?

✅ **Oui, absolument!**

**Approche recommandée:**

1. **docker-build.yml** - Principal
   - Build et push vers deux registres
   - Tests automatisés
   - Image slim
   
2. **build-deploy.yml** - Déploiement
   - Renommez en `deploy.yml`
   - Retirez la partie build
   - Gardez deploy + migrations
   - Déclenché par docker-build.yml

**Exemple de configuration combinée:**

```yaml
# docker-build.yml
on:
  push:
    branches: [main, develop]
  # ... reste du workflow

jobs:
  build-and-push:
    # ... build et push
    
  trigger-deploy:
    needs: build-and-push
    if: github.ref == 'refs/heads/main'
    uses: ./.github/workflows/deploy.yml
    secrets: inherit
```

## Migration de build-deploy.yml vers docker-build.yml

Si vous voulez migrer:

1. **Sauvegarder l'ancien workflow**
   ```bash
   mv .github/workflows/build-deploy.yml .github/workflows/build-deploy.yml.backup
   ```

2. **Activer le nouveau**
   - Le fichier `docker-build.yml` est déjà présent
   
3. **Configurer les secrets**
   - Ajouter `SCW_REGISTRY_PASSWORD` dans GitHub

4. **Tester sur une branche feature**
   ```bash
   git checkout -b test/new-workflow
   git push origin test/new-workflow
   # Vérifier dans Actions que le build fonctionne
   ```

5. **Adapter le déploiement**
   - Utiliser ArgoCD, Flux, ou autre
   - Ou garder deploy séparément

## Secrets requis

**build-deploy.yml:**
```
GITHUB_TOKEN (automatique)
KUBECONFIG_STAGING (optionnel)
KUBECONFIG_PRODUCTION (optionnel)
```

**docker-build.yml:**
```
GITHUB_TOKEN (automatique)
SCW_REGISTRY_PASSWORD (requis pour Scaleway)
```

## Conclusion

| Critère | build-deploy.yml | docker-build.yml |
|---------|------------------|------------------|
| **Simplicité** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Flexibilité** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Redondance** | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Tests** | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Sécurité** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Déploiement** | ⭐⭐⭐⭐⭐ | ⭐ |
| **Économies** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

**Recommandation générale:**
- 🚀 **Débutants**: build-deploy.yml
- 💼 **Production**: docker-build.yml
- 🎯 **Idéal**: Les deux combinés

## Support

Pour toute question, consultez:
- [WORKFLOW_DUAL_REGISTRY.md](WORKFLOW_DUAL_REGISTRY.md) - Guide docker-build.yml
- [README.md](README.md) - Vue d'ensemble
- [USAGE_EXAMPLES.md](USAGE_EXAMPLES.md) - Exemples pratiques
