# Docker Skill — Node.js Multi-stage Build + Compose + CI/CD

## Dockerfile — Multi-stage Build for Node.js

```dockerfile
# Dockerfile
# syntax=docker/dockerfile:1

ARG NODE_VERSION=20

# ─────────────────────────────────────────
# Stage 1: deps — install production deps
# ─────────────────────────────────────────
FROM node:${NODE_VERSION}-alpine AS deps
WORKDIR /app

COPY package.json package-lock.json ./
# ci for reproducible installs; omit dev deps
RUN npm ci --omit=dev

# ─────────────────────────────────────────
# Stage 2: builder — compile TypeScript
# ─────────────────────────────────────────
FROM node:${NODE_VERSION}-alpine AS builder
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci  # includes devDependencies for build

COPY tsconfig.json ./
COPY src ./src
RUN npm run build  # outputs to dist/

# ─────────────────────────────────────────
# Stage 3: production — minimal runtime image
# ─────────────────────────────────────────
FROM node:${NODE_VERSION}-alpine AS production
WORKDIR /app

ENV NODE_ENV=production

# Non-root user for security
RUN addgroup -g 1001 -S nodejs && adduser -S appuser -u 1001 -G nodejs
USER appuser

# Copy only what's needed
COPY --from=deps --chown=appuser:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=appuser:nodejs /app/dist ./dist
COPY --chown=appuser:nodejs package.json ./

EXPOSE 3000

# Healthcheck built into image
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "dist/server.js"]
```

## docker-compose.yml — Development Environment

```yaml
# docker-compose.yml
version: '3.9'

services:
  api:
    build:
      context: .
      target: builder          # Use builder stage for dev (has devDeps)
    command: npm run dev        # Uses ts-node-dev or tsx watch
    volumes:
      - ./src:/app/src:delegated  # Hot reload: mount source only
      - /app/node_modules         # Anonymous volume to protect node_modules
    ports:
      - "3000:3000"
      - "9229:9229"              # Node.js debugger port
    env_file:
      - .env
    environment:
      NODE_ENV: development
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${DB_USER:-appuser}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-devpassword}
      POSTGRES_DB: ${DB_NAME:-appdb}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./db/migrations:/docker-entrypoint-initdb.d:ro  # auto-run on first init
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-appuser} -d ${DB_NAME:-appdb}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD:-devpassword}
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "--pass", "${REDIS_PASSWORD:-devpassword}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
  redis_data:
```

## docker-compose.prod.yml — Production Overrides

```yaml
# docker-compose.prod.yml
# Usage: docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
version: '3.9'

services:
  api:
    build:
      target: production       # Use the slim production stage
    command: node dist/server.js
    volumes: []                # No source mounts in prod
    ports:
      - "3000:3000"
    environment:
      NODE_ENV: production
    secrets:
      - db_password
      - jwt_secret
    deploy:
      replicas: 2
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first     # Zero-downtime rolling update
      restart_policy:
        condition: on-failure
        max_attempts: 3
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  postgres:
    ports: []                  # Do NOT expose DB port in prod
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password

  nginx:
    image: nginx:1.25-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/certs:/etc/nginx/certs:ro
    depends_on:
      - api

secrets:
  db_password:
    file: ./secrets/db_password.txt
  jwt_secret:
    file: ./secrets/jwt_secret.txt
```

## Health Check Pattern (Express endpoint)

```ts
// src/routes/health.routes.ts
import { Router } from 'express';
import { pool } from '../config/database';
import { redis } from '../config/redis';

export const healthRouter = Router();

healthRouter.get('/health', async (_req, res) => {
  const checks: Record<string, 'ok' | 'error'> = {};

  // DB check
  try {
    await pool.query('SELECT 1');
    checks.database = 'ok';
  } catch {
    checks.database = 'error';
  }

  // Redis check
  try {
    await redis.ping();
    checks.redis = 'ok';
  } catch {
    checks.redis = 'error';
  }

  const isHealthy = Object.values(checks).every((v) => v === 'ok');
  res.status(isHealthy ? 200 : 503).json({ status: isHealthy ? 'ok' : 'degraded', checks });
});
```

## Env Var Management

```
# .env.example — committed to git, no real values
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://appuser:CHANGEME@postgres:5432/appdb
REDIS_URL=redis://:CHANGEME@redis:6379
JWT_SECRET=CHANGEME_min_32_chars
JWT_REFRESH_SECRET=CHANGEME_min_32_chars
CORS_ORIGIN=http://localhost:3001

# .env — gitignored, real values for local dev
# .env.prod — stored in encrypted secrets manager, never in repo
```

`.dockerignore`:
```
.git
.env
.env.prod
node_modules
dist
*.log
.DS_Store
```

## Volume Strategy

| Data type           | Volume strategy                                    |
|---------------------|----------------------------------------------------|
| PostgreSQL data     | Named volume `postgres_data` — never bind mount    |
| Redis data          | Named volume `redis_data` with AOF persistence     |
| App source (dev)    | Bind mount `./src:/app/src` for hot reload         |
| App source (prod)   | Baked into image — no bind mounts                  |
| Uploaded files      | Bind mount to `/data/uploads` on host + backup     |
| Logs                | json-file driver or forward to external aggregator |

## GitHub Actions — Build + Push Image

```yaml
# .github/workflows/docker.yml
name: Build and Push Docker Image

on:
  push:
    branches: [main]
    tags: ['v*']

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix=sha-

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          target: production
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          build-args: |
            NODE_VERSION=20
```
