# Testing Skill — Vitest + Supertest + TypeScript

## Folder Structure

```
src/
├── services/
│   └── auth.service.ts
│   └── auth.service.test.ts    # Co-located unit tests (preferred for units)
tests/
├── integration/
│   ├── auth.test.ts            # Full HTTP round-trips with Supertest
│   └── user.test.ts
├── fixtures/
│   ├── users.fixture.ts        # Static fixture data
│   └── index.ts
├── factories/
│   ├── user.factory.ts         # Dynamic test data factories
│   └── index.ts
└── setup/
    ├── global-setup.ts         # Run once before all tests (DB setup)
    ├── setup.ts                # Run before each test file
    └── test-db.ts              # Test database helpers
```

## Vitest Config

```ts
// vitest.config.ts
import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  test: {
    globals: true,              // no need to import describe/it/expect
    environment: 'node',
    setupFiles: ['./tests/setup/setup.ts'],
    globalSetup: ['./tests/setup/global-setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov', 'html'],
      thresholds: {
        lines: 80,
        functions: 80,
        branches: 70,
        statements: 80,
      },
      exclude: [
        'node_modules/**',
        'dist/**',
        '**/*.types.ts',
        '**/index.ts',
        'tests/**',
      ],
    },
    testTimeout: 10_000,
  },
  resolve: {
    alias: { '@': path.resolve(__dirname, 'src') },
  },
});
```

## Unit Test Pattern

```ts
// src/services/auth.service.test.ts
import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import { signAccessToken, verifyAccessToken } from './auth.service';
import { AppError } from '../utils/app-error';

// Mock config before importing the module
vi.mock('../config/env', () => ({
  config: {
    JWT_SECRET: 'test-secret-that-is-at-least-32-chars-long',
    JWT_REFRESH_SECRET: 'test-refresh-secret-that-is-at-least-32-chars',
  },
}));

describe('AuthService', () => {
  describe('signAccessToken', () => {
    it('returns a JWT string for valid payload', () => {
      const token = signAccessToken({ userId: 'user-1', role: 'user' });
      expect(typeof token).toBe('string');
      expect(token.split('.')).toHaveLength(3); // valid JWT structure
    });

    it('includes userId and role in token payload', () => {
      const token = signAccessToken({ userId: 'user-1', role: 'admin' });
      const payload = verifyAccessToken(token);
      expect(payload.userId).toBe('user-1');
      expect(payload.role).toBe('admin');
    });
  });

  describe('verifyAccessToken', () => {
    it('returns payload for a valid token', () => {
      const token = signAccessToken({ userId: 'user-1', role: 'user' });
      const payload = verifyAccessToken(token);
      expect(payload).toMatchObject({ userId: 'user-1', role: 'user' });
    });

    it('throws AppError.unauthorized for an invalid token', () => {
      expect(() => verifyAccessToken('not.a.token')).toThrow(AppError);
      expect(() => verifyAccessToken('not.a.token')).toThrow('Invalid or expired access token');
    });

    it('throws for an expired token', () => {
      vi.useFakeTimers();
      const token = signAccessToken({ userId: 'user-1', role: 'user' });
      vi.advanceTimersByTime(16 * 60 * 1000); // 16 minutes > 15m TTL
      expect(() => verifyAccessToken(token)).toThrow(AppError);
      vi.useRealTimers();
    });
  });
});
```

## Mock Pattern: vi.mock + vi.spyOn

```ts
// Mocking a module — always at the top level
vi.mock('../repositories/user.repository', () => ({
  UserRepository: vi.fn().mockImplementation(() => ({
    findById: vi.fn(),
    findByEmail: vi.fn(),
    create: vi.fn(),
  })),
}));

// In test: configure mock return values per test
import { UserRepository } from '../repositories/user.repository';
const mockRepo = vi.mocked(new UserRepository(null as never));

beforeEach(() => {
  vi.clearAllMocks(); // reset call counts + implementations between tests
});

it('returns user when found', async () => {
  const fakeUser = userFactory.build();
  mockRepo.findById.mockResolvedValueOnce(fakeUser);

  const result = await userService.getUserById('user-1');
  expect(result).toEqual(fakeUser);
  expect(mockRepo.findById).toHaveBeenCalledWith('user-1');
  expect(mockRepo.findById).toHaveBeenCalledOnce();
});

// vi.spyOn for partial mocks — spy on specific method of a real module
import * as cacheModule from '../utils/cache';
const cacheSpy = vi.spyOn(cacheModule, 'withCache').mockImplementation(
  async (_key, _ttl, fetchFn) => fetchFn() // bypass cache in tests
);
```

## Integration Test Pattern (Supertest)

```ts
// tests/integration/auth.test.ts
import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../../src/app';
import { pool } from '../../src/config/database';
import { seedTestUser, cleanTestData } from '../setup/test-db';

const app = createApp();

describe('POST /api/v1/auth/login', () => {
  beforeAll(async () => {
    await seedTestUser({ email: 'test@example.com', password: 'Password123!' });
  });

  afterAll(async () => {
    await cleanTestData();
  });

  it('returns 200 with access token for valid credentials', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'test@example.com', password: 'Password123!' });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ accessToken: expect.any(String) });
    expect(res.body.error).toBeNull();
    expect(res.headers['set-cookie']).toBeDefined(); // refresh token cookie
  });

  it('returns 401 for wrong password', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'test@example.com', password: 'wrong' });

    expect(res.status).toBe(401);
    expect(res.body.data).toBeNull();
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('returns 400 for invalid email format', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'not-an-email', password: 'Password123!' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });
});
```

## Factory Pattern for Test Data

```ts
// tests/factories/user.factory.ts
import { faker } from '@faker-js/faker';

interface UserFactoryOptions {
  id?: string;
  email?: string;
  name?: string;
  role?: 'user' | 'admin';
}

export const userFactory = {
  build: (overrides: UserFactoryOptions = {}): User => ({
    id: overrides.id ?? faker.string.uuid(),
    email: overrides.email ?? faker.internet.email().toLowerCase(),
    name: overrides.name ?? faker.person.fullName(),
    role: overrides.role ?? 'user',
    emailVerified: false,
    createdAt: new Date(),
    updatedAt: new Date(),
    deletedAt: null,
  }),

  buildList: (count: number, overrides: UserFactoryOptions = {}): User[] =>
    Array.from({ length: count }, () => userFactory.build(overrides)),
};
```

## Coverage Thresholds in CI

```yaml
# .github/workflows/test.yml
- name: Run tests with coverage
  run: npm run test:coverage

- name: Upload coverage report
  uses: codecov/codecov-action@v4
  with:
    files: ./coverage/lcov.info
    fail_ci_if_error: true
    threshold: 80
```

```json
// package.json scripts
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage",
    "test:integration": "vitest run tests/integration"
  }
}
```
