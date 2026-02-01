# Guide du Workflow Dual-Registry (Scaleway + GHCR)

## Vue d'ensemble

Ce guide explique comment utiliser le workflow GitHub Actions `docker-build.yml` qui construit et pousse automatiquement les images Docker vers deux registres :
- **Scaleway Container Registry** (SCW)
- **GitHub Container Registry** (GHCR)

## Table des matières

1. [Configuration initiale](#configuration-initiale)
2. [Comportement du workflow](#comportement-du-workflow)
3. [Variantes d'images](#variantes-dimages)
4. [Stratégie de tagging](#stratégie-de-tagging)
5. [Tests automatisés](#tests-automatisés)
6. [Utilisation des images](#utilisation-des-images)
7. [Dépannage](#dépannage)

## Configuration initiale

### 1. Secrets GitHub requis

Configurez ces secrets dans votre repository GitHub :

**Settings → Secrets and variables → Actions → New repository secret**

| Secret | Description | Obligatoire |
|--------|-------------|-------------|
| `SCW_REGISTRY_PASSWORD` | Mot de passe Scaleway Container Registry | ✅ Oui |
| `GITHUB_TOKEN` | Token GitHub (automatique) | ✅ Auto-fourni |

#### Obtenir le mot de passe Scaleway

1. Connectez-vous à la console Scaleway
2. Allez dans **Container Registry**
3. Sélectionnez votre registry (ex: `registry-ixys-dev`)
4. Générez un token d'accès
5. Copiez le mot de passe et ajoutez-le comme secret GitHub

### 2. Vérifier la configuration du workflow

Le workflow est configuré dans `.github/workflows/docker-build.yml` avec ces variables :

```yaml
env:
  IMAGE_NAME: ${{ github.event.repository.name }}
  REGISTRY_SCW: rg.fr-par.scw.cloud/registry-ixys-dev
  REGISTRY_GHCR: ghcr.io/${{ github.repository_owner }}
```

**À adapter selon votre setup :**
- `REGISTRY_SCW` : Changez `registry-ixys-dev` par le nom de votre registry Scaleway
- `REGISTRY_GHCR` : Automatiquement configuré avec votre username/org GitHub

## Comportement du workflow

### Déclencheurs

Le workflow se déclenche sur :

| Événement | Branches | Action |
|-----------|----------|--------|
| **Push** | `main`, `develop`, `feature/*` | Build + Test + Push conditionnel |
| **Pull Request** | vers `main` ou `develop` | Build + Test seulement |
| **Release** | Published | Build + Test + Push |
| **Manual** | Dispatch | Build + Test + Push conditionnel |

### Logique de push

Les images sont **poussées vers les registres** uniquement si :

✅ **Push sur branche `main`** 
✅ **Push sur branche `develop`**
✅ **Release publiée** (événement `release.published`)

❌ **PAS de push** pour :
- Pull requests
- Branches `feature/*`
- Autres branches

**Exemple de flux :**

```
feature/nouvelle-fonctionnalité
  ↓ push
  └─→ Build + Test ✅ (pas de push)
  
  ↓ PR vers develop
  └─→ Build + Test ✅ (pas de push)
  
  ↓ Merge dans develop
  └─→ Build + Test + Push SCW + Push GHCR ✅

  ↓ PR vers main
  └─→ Build + Test ✅ (pas de push)
  
  ↓ Merge dans main
  └─→ Build + Test + Push SCW + Push GHCR ✅
  
  ↓ Release v1.2.3
  └─→ Build + Test + Push SCW + Push GHCR ✅
```

## Variantes d'images

### Image Full (`app` target)

**Contenu complet pour production standard**

Inclus :
- ✅ FrankenPHP + PHP 8.4
- ✅ Extensions PHP (pdo_mysql, redis, gd, intl, zip, bcmath, etc.)
- ✅ OPcache avec JIT
- ✅ Git, curl, wget
- ✅ Vim, nano (éditeurs)
- ✅ Doppler CLI (secrets management)
- ✅ Supervisor

**Taille approximative :** ~800 MB

**Recommandé pour :**
- Production standard
- Environnements nécessitant des outils de debug
- Déploiements où git est requis
- Utilisation de Doppler pour les secrets

### Image Slim (`slim` target)

**Image minimale optimisée**

Retiré :
- ❌ Git
- ❌ Curl, wget
- ❌ Vim, nano
- ❌ Doppler CLI
- ❌ Outils de développement

Conservé :
- ✅ FrankenPHP + PHP 8.4
- ✅ Toutes les extensions PHP
- ✅ OPcache avec JIT
- ✅ Supervisor
- ✅ Bibliothèques runtime essentielles

**Taille approximative :** ~650 MB (20% plus petit)

**Recommandé pour :**
- Déploiements edge/IoT
- Environnements avec contraintes de bande passante
- Registres avec quotas de stockage
- Environnements sécurisés (surface d'attaque réduite)
- Kubernetes avec pull fréquents

## Stratégie de tagging

### Format des tags

Chaque build génère plusieurs tags automatiquement :

#### Sur événement Push

**Image Full :**
```
{registry}/{image}:{branch}_{sha}      # Ex: main_abc1234
{registry}/{image}:{branch}            # Ex: main, develop
{registry}/{image}:latest              # Seulement sur main
```

**Image Slim :**
```
{registry}/{image}:{branch}_{sha}-slim
{registry}/{image}:{branch}-slim
{registry}/{image}:slim                # Seulement sur main
```

#### Sur événement Release

En plus des tags ci-dessus :

**Image Full :**
```
{registry}/{image}:{version}           # Ex: v1.2.3
```

**Image Slim :**
```
{registry}/{image}:{version}-slim      # Ex: v1.2.3-slim
```

### Exemples concrets

**Repository :** `jsimoncini/docker-laravel-frankenphp-8.4`  
**Commit :** `abc1234`  
**Branche :** `main`

**Tags créés sur Scaleway :**
```
rg.fr-par.scw.cloud/registry-ixys-dev/docker-laravel-frankenphp-8.4:main_abc1234
rg.fr-par.scw.cloud/registry-ixys-dev/docker-laravel-frankenphp-8.4:main
rg.fr-par.scw.cloud/registry-ixys-dev/docker-laravel-frankenphp-8.4:latest
rg.fr-par.scw.cloud/registry-ixys-dev/docker-laravel-frankenphp-8.4:main_abc1234-slim
rg.fr-par.scw.cloud/registry-ixys-dev/docker-laravel-frankenphp-8.4:main-slim
rg.fr-par.scw.cloud/registry-ixys-dev/docker-laravel-frankenphp-8.4:slim
```

**Tags créés sur GHCR :**
```
ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:main_abc1234
ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:main
ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:latest
ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:main_abc1234-slim
ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:main-slim
ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:slim
```

## Tests automatisés

### Tests exécutés

Pour chaque variante d'image (full et slim) :

1. **Version PHP**
   ```bash
   docker run --rm {image} php -v
   ```

2. **Extensions PHP requises**
   ```bash
   docker run --rm {image} php -m | grep -E 'bcmath|gd|intl|...'
   ```

3. **Binaire FrankenPHP**
   ```bash
   docker run --rm {image} frankenphp version
   ```

4. **Health check endpoint**
   ```bash
   # Démarre le container
   # Attend 10 secondes
   # Teste http://localhost/up
   # Vérifie réponse "OK"
   ```

### En cas d'échec

Si un test échoue :
- ❌ Le workflow s'arrête
- ❌ Aucune image n'est poussée
- 📧 Notification GitHub
- 📋 Logs disponibles dans l'onglet Actions

## Utilisation des images

### Pull depuis GHCR (recommandé pour GitHub)

```bash
# Image full latest
docker pull ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:latest

# Image slim latest
docker pull ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:slim

# Version spécifique
docker pull ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:v1.2.3

# Branch develop
docker pull ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:develop

# Commit spécifique
docker pull ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:main_abc1234
```

### Pull depuis Scaleway

```bash
# Image full latest
docker pull rg.fr-par.scw.cloud/registry-ixys-dev/docker-laravel-frankenphp-8.4:latest

# Image slim latest
docker pull rg.fr-par.scw.cloud/registry-ixys-dev/docker-laravel-frankenphp-8.4:slim

# Version spécifique
docker pull rg.fr-par.scw.cloud/registry-ixys-dev/docker-laravel-frankenphp-8.4:v1.2.3
```

### Dans docker-compose.yml

```yaml
services:
  app:
    # GHCR
    image: ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:latest
    
    # Ou Scaleway
    # image: rg.fr-par.scw.cloud/registry-ixys-dev/docker-laravel-frankenphp-8.4:latest
    
    # Ou slim
    # image: ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:slim
```

### Dans Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: laravel-app
spec:
  template:
    spec:
      containers:
      - name: app
        # GHCR
        image: ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:v1.2.3
        
        # Ou Scaleway
        # image: rg.fr-par.scw.cloud/registry-ixys-dev/docker-laravel-frankenphp-8.4:v1.2.3
        
        # Ou slim
        # image: ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:v1.2.3-slim
      imagePullSecrets:
      - name: registry-credentials
```

### Authentification pour pull privé

**GHCR :**
```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

**Scaleway :**
```bash
echo $SCW_PASSWORD | docker login rg.fr-par.scw.cloud/registry-ixys-dev -u nologin --password-stdin
```

## Dépannage

### Erreur : "SCW_REGISTRY_PASSWORD not set"

**Cause :** Secret Scaleway non configuré

**Solution :**
1. Allez dans Settings → Secrets and variables → Actions
2. Créez le secret `SCW_REGISTRY_PASSWORD`
3. Relancez le workflow

### Erreur : "docker login failed"

**Cause :** Mot de passe Scaleway incorrect ou expiré

**Solution :**
1. Régénérez un token dans la console Scaleway
2. Mettez à jour le secret GitHub
3. Relancez le workflow

### Les images ne sont pas poussées

**Vérifiez :**
- ✅ Êtes-vous sur `main` ou `develop` ?
- ✅ Est-ce un push direct (pas une PR) ?
- ✅ Le secret `SCW_REGISTRY_PASSWORD` est-il configuré ?

**Logs à vérifier :**
```
Will push images? true
Pushing images to SCW...
Pushing images to GHCR...
```

### Tests health check échouent

**Cause possible :** Container ne démarre pas correctement

**Debug :**
```bash
# Localement
docker run -it --rm -p 8080:80 {image}

# Tester health check
curl http://localhost:8080/up
```

### Build très lent

**Cause :** Cache Docker non optimisé

**Solutions :**
- Le workflow essaie de puller les images `latest` pour le cache
- Sur premier build d'une branche, c'est normal (pas de cache)
- Builds suivants seront plus rapides

### Image trop volumineuse

**Solution :** Utilisez l'image slim

```bash
# Au lieu de
docker pull ghcr.io/.../app:latest

# Utilisez
docker pull ghcr.io/.../app:slim
```

## Bonnes pratiques

### 1. Tagging sémantique

Utilisez les releases GitHub avec tags sémantiques :

```bash
git tag v1.2.3
git push origin v1.2.3
```

Puis créez une release sur GitHub → déclenche le workflow avec tag `v1.2.3`.

### 2. Choisir la bonne variante

| Cas d'usage | Recommandation |
|-------------|----------------|
| Production standard | **Full** |
| Edge/IoT | **Slim** |
| Debug nécessaire | **Full** |
| CI/CD avec git | **Full** |
| Environnement sécurisé | **Slim** |
| Quotas de stockage limités | **Slim** |

### 3. Pin des versions en production

❌ **À éviter :**
```yaml
image: ghcr.io/.../app:latest
```

✅ **Recommandé :**
```yaml
image: ghcr.io/.../app:v1.2.3
```

### 4. Redondance des registres

Utilisez les deux registres pour la redondance :

```yaml
# Primary: GHCR
image: ghcr.io/.../app:v1.2.3

# Fallback si GHCR down
# image: rg.fr-par.scw.cloud/.../app:v1.2.3
```

### 5. Multi-architecture

Les images supportent `linux/amd64` et `linux/arm64` :

```bash
# Automatiquement la bonne arch
docker pull ghcr.io/.../app:latest

# Force amd64
docker pull --platform linux/amd64 ghcr.io/.../app:latest

# Force arm64 (Apple Silicon, Graviton)
docker pull --platform linux/arm64 ghcr.io/.../app:latest
```

## Support

Pour toute question ou problème :
1. Vérifiez les logs dans l'onglet **Actions** de GitHub
2. Consultez cette documentation
3. Ouvrez une issue sur le repository

## Changelog

- **2026-02-01** : Version initiale du workflow dual-registry
  - Support Scaleway + GHCR
  - Variantes full et slim
  - Multi-architecture (amd64, arm64)
  - Tests automatisés
  - Push conditionnel
