# Contributing to Docker Laravel FrankenPHP

Thank you for your interest in improving this Docker setup! This guide will help you maintain and enhance the project while preserving its core optimization principles.

## Core Principles

Before making changes, please understand these fundamental principles:

1. **Cache Efficiency First**: Layer ordering is critical. Changes must not reduce cache hit rates.
2. **No Functional Regression**: All Laravel 11 and FrankenPHP features must continue working.
3. **Security By Default**: Non-root users, minimal attack surface, regular updates.
4. **Production Ready**: Configurations must be production-grade, not just development-friendly.
5. **Documentation Required**: All changes must be documented.

## Making Changes

### Before You Start

1. **Test Current Setup**
   ```bash
   ./validate.sh
   ```

2. **Understand Layer Order**
   Read `DOCKER_OPTIMIZATION.md` to understand why layers are ordered as they are.

3. **Check Existing Issues**
   Look for similar proposals or discussions in GitHub issues.

### Types of Changes

#### 1. Adding PHP Extensions

**Where**: In the `base-runtime` stage of `Dockerfile`

**Example**:
```dockerfile
RUN docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    mysqli \
    mbstring \
    # ... existing extensions ...
    your_new_extension  # Add at the end
```

**Important**: 
- Add to existing RUN command to avoid new layers
- Update README with the new extension
- Test that it doesn't break existing functionality

#### 2. Modifying OPcache Configuration

**Where**: In the `base-runtime` stage, OPcache configuration section

**Example**:
```dockerfile
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=256'; \
    # ... existing settings ...
    echo 'opcache.your_setting=value'; \
    } > /usr/local/etc/php/conf.d/opcache-prod.ini
```

**Important**:
- Document why the change is needed
- Provide benchmarks if changing performance settings
- Consider impact on all Laravel applications

#### 3. Adding System Packages

**Where**: In the `base-runtime` stage, system dependencies section

**Example**:
```dockerfile
RUN apt-get update && apt-get install -y \
    git \
    curl \
    # ... existing packages ...
    your-new-package \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

**Important**:
- Add to existing RUN command (single layer)
- Include cleanup commands
- Justify why the package is needed
- Consider image size impact

#### 4. Modifying Caddyfile

**Where**: `Caddyfile`

**Important**:
- Test with FrankenPHP locally
- Ensure Octane compatibility
- Verify health check still works
- Update documentation

#### 5. Changing Docker Compose Setup

**Where**: `docker-compose.yml`

**Important**:
- Maintain backward compatibility
- Test with `docker-compose up`
- Verify all services start correctly
- Update README if behavior changes

### Testing Your Changes

1. **Validate Structure**
   ```bash
   ./validate.sh
   ```

2. **Build All Stages**
   ```bash
   docker build --target base-runtime -t test-base:latest .
   docker build --target dependencies -t test-deps:latest .
   docker build --target frontend-builder -t test-frontend:latest .
   docker build --target app -t test-app:latest .
   docker build --target dev -t test-dev:latest .
   ```

3. **Test Cache Efficiency**
   ```bash
   # First build (cold cache)
   time docker build --target app -t test:v1 .
   
   # Second build (should be fast)
   time docker build --target app -t test:v2 .
   
   # Change should take < 1 minute if only code changed
   ```

4. **Test Runtime**
   ```bash
   docker run -d -p 8080:80 test-app:latest
   curl http://localhost:8080/up
   # Should return "OK"
   ```

5. **Test with Compose**
   ```bash
   docker-compose up -d
   docker-compose ps
   docker-compose logs app
   # Verify no errors
   ```

### Performance Testing

When making performance-related changes, provide benchmarks:

```bash
# Before changes
ab -n 1000 -c 10 http://localhost/

# After changes
ab -n 1000 -c 10 http://localhost/

# Compare results
```

### Documentation Requirements

All changes must update relevant documentation:

1. **README.md**: User-facing features and usage
2. **DOCKER_OPTIMIZATION.md**: Technical details about optimizations
3. **Inline Comments**: Complex Dockerfile instructions
4. **CHANGELOG.md**: Notable changes (if major version)

## Pull Request Guidelines

### PR Title Format

```
[Type] Brief description

Types:
- feat: New feature
- fix: Bug fix
- docs: Documentation only
- perf: Performance improvement
- refactor: Code refactoring
- test: Adding tests
- chore: Maintenance
```

### PR Description Template

```markdown
## Description
Brief description of changes

## Motivation
Why is this change needed?

## Changes
- List of specific changes
- Be detailed

## Testing
How did you test these changes?

## Performance Impact
- Build time: before/after
- Image size: before/after
- Runtime: before/after (if applicable)

## Checklist
- [ ] Validated with ./validate.sh
- [ ] Tested all build stages
- [ ] Tested runtime functionality
- [ ] Updated documentation
- [ ] No cache efficiency regression
- [ ] No security regressions
```

## Common Issues and Solutions

### Issue: Layer Cache Not Working

**Symptom**: Every build rebuilds everything

**Solution**: 
1. Check layer order with `docker history`
2. Ensure files aren't changing unnecessarily
3. Verify .dockerignore is correct
4. Use `docker build --no-cache` to test fresh builds

### Issue: Large Image Size

**Symptom**: Final image > 1GB

**Solution**:
1. Ensure cleanup commands are in same RUN layer
2. Use multi-stage builds properly
3. Check .dockerignore excludes unnecessary files
4. Remove development dependencies

### Issue: Slow Composer Install

**Symptom**: composer install takes > 5 minutes

**Solution**:
1. Use `--prefer-dist` flag
2. Consider composer cache mount
3. Check network connectivity
4. Verify composer.lock is committed

## Version Support

### PHP Version Updates

When updating PHP version (e.g., 8.4 to 8.5):

1. Update base image in Dockerfile
2. Test all PHP extensions compile
3. Update README
4. Create new branch for testing
5. Monitor for compatibility issues

### Laravel Version Updates

When updating Laravel (e.g., 11 to 12):

1. Review Laravel upgrade guide
2. Update composer dependencies example
3. Test Octane compatibility
4. Update configuration examples
5. Update README

### FrankenPHP Updates

When updating FrankenPHP version:

1. Check FrankenPHP changelog
2. Test worker mode compatibility
3. Verify Caddyfile syntax
4. Update Caddyfile if needed
5. Test health checks

## Security Guidelines

1. **Never Commit Secrets**: Use .env.example only
2. **Regular Updates**: Keep base images updated
3. **Scan Images**: Use Trivy or similar tools
4. **Non-Root User**: Always run as www-data
5. **Minimal Packages**: Only install what's needed

## Release Process

1. Update version in README
2. Update CHANGELOG.md
3. Tag release: `git tag v1.x.x`
4. Push tags: `git push --tags`
5. Create GitHub release
6. Update Docker Hub (if applicable)

## Getting Help

- **Questions**: Open a GitHub Discussion
- **Bugs**: Open a GitHub Issue
- **Security**: Email maintainers directly
- **Features**: Open a GitHub Issue for discussion first

## Code of Conduct

- Be respectful and professional
- Welcome newcomers
- Focus on constructive feedback
- Assume positive intent
- Document your work

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT License).

## Thank You!

Your contributions help make this project better for everyone. Thank you for taking the time to contribute! 🙏
