---
applyTo: "**/Dockerfile*"
---

# Docker Instructions

You are an expert in Docker containerization and best practices.

## Dockerfile Best Practices

- Use official base images when possible
- Use specific image tags instead of 'latest'
- Minimize the number of layers by combining RUN commands
- Use multi-stage builds for optimization
- Run containers as non-root users
- Use .dockerignore to exclude unnecessary files
- Order instructions by frequency of change (least to most frequent)
- Use COPY instead of ADD unless you need ADD's specific features

## Security Practices

- Scan images for vulnerabilities regularly
- Use minimal base images (Alpine, distroless, scratch when possible)
- Don't include secrets in images
- Use specific user IDs instead of usernames
- Remove package managers and unnecessary tools in production images
- Use read-only root filesystems when possible
- Implement proper secret management
- Keep base images updated

## Image Optimization

- Use multi-stage builds to reduce final image size
- Clean up package caches and temporary files
- Use .dockerignore effectively
- Minimize installed packages
- Use appropriate base images for the use case
- Implement proper layer caching strategies
- Use Docker BuildKit for advanced features

## Container Runtime

- Set proper resource limits (memory, CPU)
- Use health checks for container monitoring
- Implement proper logging strategies
- Use proper signal handling for graceful shutdowns
- Mount volumes appropriately
- Use proper networking configurations
- Implement proper restart policies

## Docker Compose

- Use version 3.x format
- Organize services logically
- Use environment files for configuration
- Implement proper service dependencies
- Use proper volume management
- Implement proper networking between services
- Use profiles for different environments

## Production Considerations

- Use orchestration platforms (Kubernetes, Docker Swarm)
- Implement proper monitoring and logging
- Use proper image registries with access controls
- Implement automated vulnerability scanning
- Use proper backup and disaster recovery strategies
- Implement proper CI/CD integration
- Use configuration management for different environments

## Common Patterns

Base Image Selection:
- Use Alpine for minimal size requirements
- Use Ubuntu/Debian for compatibility requirements
- Use distroless for security-focused applications
- Use scratch for static binaries

Application Patterns:
- Use multi-stage builds for compiled languages
- Implement proper application user creation
- Use proper working directory setup
- Implement proper signal handling
- Use proper health check endpoints

## Dockerfile Structure

```dockerfile
# Use specific base image
FROM node:18-alpine AS base

# Set working directory
WORKDIR /app

# Install dependencies first (for better caching)
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy application code
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# Set proper ownership
RUN chown -R nextjs:nodejs /app
USER nextjs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start application
CMD ["npm", "start"]
```

## Debugging and Troubleshooting

- Use docker logs for container output
- Use docker exec for debugging running containers
- Implement proper logging in applications
- Use multi-stage builds for debug vs production images
- Use proper tag management for different environments
- Implement proper monitoring and alerting
