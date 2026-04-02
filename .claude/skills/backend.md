# Backend Skill — Node.js + Express + TypeScript

## Project Structure

```
src/
├── app.ts                  # Express app factory (no listen() here)
├── server.ts               # Entry point: calls app.listen()
├── config/
│   ├── env.ts              # Zod-validated env config (export const config)
│   └── logger.ts           # Pino logger instance
├── routes/
│   ├── index.ts            # Mount all routers: app.use('/api/v1', router)
│   ├── auth.routes.ts
│   └── user.routes.ts
├── controllers/
│   ├── auth.controller.ts  # HTTP layer only: parse req, call service, respond
│   └── user.controller.ts
├── services/
│   ├── auth.service.ts     # Business logic, orchestrates repositories
│   └── user.service.ts
├── repositories/
│   ├── user.repository.ts  # All DB queries for a single entity
│   └── session.repository.ts
├── middlewares/
│   ├── auth.middleware.ts  # JWT verification
│   ├── validate.middleware.ts
│   └── error.middleware.ts # Global error handler (MUST be last)
├── types/
│   ├── express.d.ts        # Augment Express Request type
│   └── api.types.ts        # ApiResponse, Pagination, etc.
└── utils/
    ├── async-handler.ts
    └── response.ts
```

## AppError Class Pattern

```ts
// src/utils/app-error.ts
export class AppError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly code: string,
    message: string,
    public readonly details?: unknown
  ) {
    super(message);
    this.name = 'AppError';
    Error.captureStackTrace(this, this.constructor);
  }

  static badRequest(message: string, details?: unknown): AppError {
    return new AppError(400, 'BAD_REQUEST', message, details);
  }
  static unauthorized(message = 'Unauthorized'): AppError {
    return new AppError(401, 'UNAUTHORIZED', message);
  }
  static forbidden(message = 'Forbidden'): AppError {
    return new AppError(403, 'FORBIDDEN', message);
  }
  static notFound(resource: string): AppError {
    return new AppError(404, 'NOT_FOUND', `${resource} not found`);
  }
  static conflict(message: string): AppError {
    return new AppError(409, 'CONFLICT', message);
  }
  static internal(message = 'Internal server error'): AppError {
    return new AppError(500, 'INTERNAL_ERROR', message);
  }
}
```

## Global Error Handler (must register LAST in app.ts)

```ts
// src/middlewares/error.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { AppError } from '../utils/app-error';
import { logger } from '../config/logger';
import { ZodError } from 'zod';

export function globalErrorHandler(
  err: unknown,
  req: Request,
  res: Response,
  _next: NextFunction
): void {
  if (err instanceof ZodError) {
    res.status(400).json({
      data: null,
      error: { code: 'VALIDATION_ERROR', message: 'Invalid input', details: err.flatten() },
    });
    return;
  }

  if (err instanceof AppError) {
    if (err.statusCode >= 500) logger.error({ err, req: { method: req.method, url: req.url } });
    res.status(err.statusCode).json({
      data: null,
      error: { code: err.code, message: err.message, details: err.details },
    });
    return;
  }

  logger.error({ err, req: { method: req.method, url: req.url } }, 'Unhandled error');
  res.status(500).json({
    data: null,
    error: { code: 'INTERNAL_ERROR', message: 'Something went wrong' },
  });
}
```

## Auth Pattern: JWT Access + Refresh Token

```ts
// src/services/auth.service.ts
import jwt from 'jsonwebtoken';
import { config } from '../config/env';
import { AppError } from '../utils/app-error';

const ACCESS_TOKEN_TTL = '15m';
const REFRESH_TOKEN_TTL = '7d';

export function signAccessToken(payload: { userId: string; role: string }): string {
  return jwt.sign(payload, config.JWT_SECRET, { expiresIn: ACCESS_TOKEN_TTL });
}

export function signRefreshToken(payload: { userId: string }): string {
  return jwt.sign(payload, config.JWT_REFRESH_SECRET, { expiresIn: REFRESH_TOKEN_TTL });
}

export function verifyAccessToken(token: string): { userId: string; role: string } {
  try {
    return jwt.verify(token, config.JWT_SECRET) as { userId: string; role: string };
  } catch {
    throw AppError.unauthorized('Invalid or expired access token');
  }
}

// Refresh token stored in httpOnly cookie — set it like this:
// res.cookie('refresh_token', refreshToken, {
//   httpOnly: true, secure: true, sameSite: 'strict', maxAge: 7 * 24 * 60 * 60 * 1000
// });
```

## Auth Middleware

```ts
// src/middlewares/auth.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { verifyAccessToken } from '../services/auth.service';

export function requireAuth(req: Request, _res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    next(AppError.unauthorized());
    return;
  }
  const token = authHeader.slice(7);
  const payload = verifyAccessToken(token); // throws AppError if invalid
  req.user = payload; // augmented via express.d.ts
  next();
}
```

## API Response Wrapper

```ts
// src/utils/response.ts
import { Response } from 'express';

export function sendSuccess<T>(
  res: Response,
  data: T,
  statusCode = 200,
  meta?: Record<string, unknown>
): void {
  res.status(statusCode).json({ data, error: null, ...(meta ? { meta } : {}) });
}

export function sendPaginated<T>(
  res: Response,
  data: T[],
  total: number,
  page: number,
  limit: number
): void {
  res.status(200).json({
    data,
    error: null,
    meta: { total, page, limit, pages: Math.ceil(total / limit) },
  });
}
```

## asyncHandler Wrapper

```ts
// src/utils/async-handler.ts
import { Request, Response, NextFunction, RequestHandler } from 'express';

export function asyncHandler(fn: RequestHandler): RequestHandler {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}
```

## Middleware Order in app.ts

```ts
// src/app.ts
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { rateLimit } from 'express-rate-limit';
import { globalErrorHandler } from './middlewares/error.middleware';
import { routes } from './routes';

export function createApp(): express.Application {
  const app = express();

  // 1. Security headers
  app.use(helmet());
  // 2. CORS
  app.use(cors({ origin: config.CORS_ORIGIN, credentials: true }));
  // 3. Rate limiting
  app.use(rateLimit({ windowMs: 15 * 60 * 1000, max: 100 }));
  // 4. Body parsing
  app.use(express.json({ limit: '10kb' }));
  // 5. Routes
  app.use('/api/v1', routes);
  // 6. Global error handler — MUST BE LAST
  app.use(globalErrorHandler);

  return app;
}
```

## Env Config with Zod Validation

```ts
// src/config/env.ts
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
  CORS_ORIGIN: z.string().url(),
});

const parsed = envSchema.safeParse(process.env);
if (!parsed.success) {
  console.error('Invalid environment variables:', parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const config = parsed.data;
```

## Logging with Pino

```ts
// src/config/logger.ts
import pino from 'pino';
import { config } from './env';

export const logger = pino({
  level: config.NODE_ENV === 'production' ? 'info' : 'debug',
  transport: config.NODE_ENV !== 'production'
    ? { target: 'pino-pretty', options: { colorize: true } }
    : undefined,
  redact: ['req.headers.authorization', 'body.password', 'body.token'],
});
```
