# syntax=docker/dockerfile:1.4
# ===================================
# BASE RUNTIME IMAGE - Multi-Architecture
# ===================================
# This stage contains all system dependencies and PHP extensions
# It rarely changes, maximizing Docker cache efficiency in CI/CD
# Supports: linux/amd64, linux/arm64
FROM --platform=$BUILDPLATFORM dunglas/frankenphp:1-php8.4-bookworm AS base-runtime

# Build arguments for multi-arch support
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

# Set working directory
WORKDIR /app

# Install system dependencies and PHP extensions in a single layer
# Grouped by purpose for maintainability
RUN apt-get update && apt-get install -y \
    # Build dependencies
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libicu-dev \
    zip \
    unzip \
    # Redis
    libredis-dev \
    # Image processing
    libjpeg-dev \
    libfreetype6-dev \
    # Process management for Octane
    supervisor \
    # Optional: Doppler CLI for secrets management
    && curl -sLf --retry 3 --tlsv1.2 --proto "=https" 'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' | gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" | tee /etc/apt/sources.list.d/doppler-cli.list \
    && apt-get update && apt-get install -y doppler \
    # Cleanup to reduce layer size
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install and configure PHP extensions
# Each extension is installed separately for clarity and debugging
# Multi-arch compatible: works on both amd64 and arm64
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    mysqli \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    intl \
    zip \
    opcache

# Display architecture information for debugging
RUN echo "Building for architecture: $(uname -m)" \
    && echo "Platform: ${TARGETPLATFORM:-unknown}"

# Install Redis extension via PECL
RUN pecl install redis \
    && docker-php-ext-enable redis

# Configure OPcache for production performance
# These settings optimize Laravel 11 for production workloads
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.max_accelerated_files=20000'; \
    echo 'opcache.validate_timestamps=0'; \
    echo 'opcache.save_comments=1'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=0'; \
    # Octane specific optimizations
    echo 'opcache.jit=tracing'; \
    echo 'opcache.jit_buffer_size=100M'; \
    } > /usr/local/etc/php/conf.d/opcache-prod.ini

# Configure PHP for production
RUN { \
    echo 'memory_limit=512M'; \
    echo 'upload_max_filesize=50M'; \
    echo 'post_max_size=50M'; \
    echo 'max_execution_time=300'; \
    # Log to stderr for Kubernetes compatibility
    echo 'error_log=/dev/stderr'; \
    echo 'log_errors=On'; \
    echo 'display_errors=Off'; \
    echo 'display_startup_errors=Off'; \
    } > /usr/local/etc/php/conf.d/laravel-prod.ini

# Configure FrankenPHP for Laravel Octane
# Worker mode for high performance
RUN { \
    echo 'expose_php=Off'; \
    echo 'max_input_vars=10000'; \
    # Octane worker settings
    echo 'variables_order=EGPCS'; \
    } > /usr/local/etc/php/conf.d/frankenphp.ini

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Set proper permissions for www-data user
RUN chown -R www-data:www-data /app

# ===================================
# DEPENDENCIES STAGE
# ===================================
# This stage installs composer dependencies
# Separated for better caching - dependencies change less frequently than app code
FROM base-runtime AS dependencies

# Copy composer files first for better layer caching
# If composer.json/lock don't change, this layer is cached
COPY --chown=www-data:www-data composer.json composer.lock /app/

# Install production dependencies without dev packages
# --no-scripts prevents running post-install scripts that need app code
# --no-autoloader prevents generating autoloader that needs app code
RUN composer install \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --prefer-dist \
    --optimize-autoloader \
    && rm -rf /root/.composer

# ===================================
# FRONTEND BUILD STAGE - Multi-Architecture
# ===================================
# This stage builds frontend assets in parallel
# Completely isolated from PHP for maximum cache efficiency
# Supports: linux/amd64, linux/arm64
FROM --platform=$BUILDPLATFORM node:20-bookworm-slim AS frontend-builder

ARG TARGETPLATFORM
ARG BUILDPLATFORM

WORKDIR /app

# Copy package files first for better caching
COPY package.json package-lock.json* /app/

# Install node dependencies
# Use npm install if package-lock.json doesn't exist (minimal setups)
RUN if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi

# Copy source files needed for build (optional files with wildcards)
# Wildcards allow COPY to succeed even if files don't exist
# This is important for minimal Laravel setups without frontend build tools
COPY vite.config.js* postcss.config.js* tailwind.config.js* /app/

# Create resources directory placeholder if it doesn't exist
# The build script doesn't need actual resources for minimal setups
RUN mkdir -p /app/resources

# Build production assets
# For minimal setups, this just creates a dummy manifest
RUN npm run build

# ===================================
# FINAL APPLICATION IMAGE
# ===================================
# This is the final production image
# It combines the base runtime with application code and built assets
FROM base-runtime AS app

# Copy vendor from dependencies stage
COPY --from=dependencies --chown=www-data:www-data /app/vendor /app/vendor

# Copy application code
# This layer changes most frequently, so it's placed after dependencies
COPY --chown=www-data:www-data . /app

# Copy built frontend assets
COPY --from=frontend-builder --chown=www-data:www-data /app/public/build /app/public/build

# Generate optimized autoloader now that we have all code
RUN composer dump-autoload --optimize --classmap-authoritative

# Create necessary directories for Laravel
RUN mkdir -p \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Health check for Kubernetes
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/up || exit 1

# Switch to www-data user for security
USER www-data

# Expose port
EXPOSE 80 443

# FrankenPHP worker mode for Laravel Octane compatibility
# Use multiple workers for production performance
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]

# ===================================
# DEVELOPMENT IMAGE (optional)
# ===================================
FROM base-runtime AS dev

# Install development tools
RUN apt-get update && apt-get install -y \
    vim \
    nano \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy application code
COPY --chown=www-data:www-data . /app

# Install all dependencies including dev
RUN composer install \
    --prefer-dist \
    --optimize-autoloader

# Create necessary directories
RUN mkdir -p \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

USER www-data

EXPOSE 80 443

CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]

# ===================================
# SLIM IMAGE (minimal production)
# ===================================
# Optimized minimal image without dev tools
# Based on app stage but removes unnecessary packages
FROM app AS slim

# Switch to root to remove packages
USER root

# Remove development and optional packages to minimize image size
RUN apt-get purge -y --auto-remove \
    git \
    vim \
    nano \
    curl \
    # Keep only essential runtime libraries
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# Remove Doppler CLI if not needed in slim variant
RUN apt-get purge -y --auto-remove doppler || true

# Switch back to www-data
USER www-data

# Slim image uses same entrypoint and configuration
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
