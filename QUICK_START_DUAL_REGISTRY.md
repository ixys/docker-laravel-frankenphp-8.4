# Quick Start - Workflow Dual-Registry

Guide rapide pour démarrer avec le workflow dual-registry (Scaleway + GHCR).

## 🚀 Configuration en 5 minutes

### Étape 1: Configurer le secret Scaleway

1. Allez sur [console.scaleway.com](https://console.scaleway.com)
2. Naviguez vers **Container Registry**
3. Sélectionnez votre registry (ex: `registry-ixys-dev`)
4. Cliquez sur **Generate token**
5. Copiez le mot de passe généré

6. Dans votre repository GitHub:
   - Allez dans **Settings** → **Secrets and variables** → **Actions**
   - Cliquez sur **New repository secret**
   - Nom: `SCW_REGISTRY_PASSWORD`
   - Valeur: Collez le mot de passe Scaleway
   - Cliquez **Add secret**

✅ **Secret configuré!**

### Étape 2: Vérifier la configuration du workflow

Ouvrez `.github/workflows/docker-build.yml` et vérifiez:

```yaml
env:
  REGISTRY_SCW: rg.fr-par.scw.cloud/registry-ixys-dev  # ← Votre registry
  REGISTRY_GHCR: ghcr.io/${{ github.repository_owner }}
```

Si votre registry Scaleway a un nom différent, modifiez `registry-ixys-dev`.

### Étape 3: Tester sur une branche feature

```bash
# Créer une branche de test
git checkout -b feature/test-workflow

# Faire un changement minimal
echo "# Test workflow" >> README.md

# Commit et push
git add README.md
git commit -m "Test dual-registry workflow"
git push origin feature/test-workflow
```

### Étape 4: Vérifier dans GitHub Actions

1. Allez dans l'onglet **Actions** de votre repository
2. Vous devriez voir le workflow "Build & Push Docker (Scaleway + GHCR)" en cours
3. Cliquez dessus pour voir les logs en temps réel

**Ce qui se passe:**
- ✅ Build de l'image full (multi-arch)
- ✅ Build de l'image slim (multi-arch)
- ✅ Tests automatisés
- ❌ **PAS de push** (c'est une branche feature)

### Étape 5: Push vers main pour publier

Une fois que tout fonctionne sur la branche feature:

```bash
# Retour sur main
git checkout main

# Merge ou faites vos modifications
git merge feature/test-workflow

# Push
git push origin main
```

**Maintenant:**
- ✅ Build de l'image full
- ✅ Build de l'image slim
- ✅ Tests automatisés
- ✅ **Push vers Scaleway** ← Publié!
- ✅ **Push vers GHCR** ← Publié!

## 📦 Utiliser les images

### Depuis GHCR

```bash
docker pull ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:latest
```

### Depuis Scaleway

```bash
docker pull rg.fr-par.scw.cloud/registry-ixys-dev/docker-laravel-frankenphp-8.4:latest
```

### Variante slim

```bash
# GHCR
docker pull ghcr.io/jsimoncini/docker-laravel-frankenphp-8.4:slim

# Scaleway
docker pull rg.fr-par.scw.cloud/registry-ixys-dev/docker-laravel-frankenphp-8.4:slim
```

## ✅ C'est tout!

Votre workflow dual-registry est configuré et fonctionnel.

## 📚 Pour aller plus loin

- [WORKFLOW_DUAL_REGISTRY.md](WORKFLOW_DUAL_REGISTRY.md) - Documentation complète
- [USAGE_EXAMPLES.md](USAGE_EXAMPLES.md) - Exemples de déploiement
- [WORKFLOWS_COMPARISON.md](WORKFLOWS_COMPARISON.md) - Comparaison des workflows

## 🆘 Problèmes ?

### Le build échoue avec "SCW_REGISTRY_PASSWORD not set"

➡️ Vérifiez que le secret est bien configuré dans GitHub Settings → Secrets

### Les images ne sont pas pushées

➡️ Vérifiez que vous êtes sur `main` ou `develop`, pas sur une PR ou branche feature

### Erreur "docker login failed"

➡️ Le token Scaleway a peut-être expiré, régénérez-en un nouveau

### Les tests échouent

➡️ Vérifiez les logs dans Actions pour voir quel test échoue exactement

## 💡 Tips

- **Testez d'abord sur une feature branch** avant de merger dans main
- **Utilisez les tags de version** pour les releases (ex: v1.2.3)
- **Choisissez slim** si vous déployez sur edge ou avez des contraintes de bande passante
- **Les deux registres** sont identiques, utilisez celui qui est le plus proche géographiquement
