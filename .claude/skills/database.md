# Database Skill — PostgreSQL + Redis

## Migration Naming and Folder Structure

```
db/
├── migrations/
│   ├── 20260101_create_users.sql
│   ├── 20260102_add_users_email_verified.sql
│   └── 20260310_create_sessions.sql
├── seeds/
│   ├── dev/
│   │   └── 001_seed_users.sql
│   └── test/
│       └── 001_seed_test_users.sql
└── migrate.ts      # Migration runner script
```

Naming rule: `YYYYMMDD_<action>_<subject>[_<detail>].sql`
- `create_<table>` — new table
- `add_<table>_<column>` — add column
- `drop_<table>_<column>` — remove column
- `alter_<table>_<column>` — modify column
- `create_<table>_<column>_index` — add index

## Migration File Template

```sql
-- Migration: 20260402_create_users.sql
-- Description: Create users table with auth fields
-- Date: 2026-04-02

-- ============================================================
-- UP
-- ============================================================
BEGIN;

CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  name          TEXT NOT NULL,
  role          TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin', 'moderator')),
  email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  -- Soft delete
  deleted_at    TIMESTAMPTZ,
  -- Audit fields
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by    UUID REFERENCES users(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique
  ON users (email) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS users_role_idx ON users (role);

-- auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMIT;

-- ============================================================
-- DOWN
-- ============================================================
BEGIN;

DROP TRIGGER IF EXISTS users_updated_at ON users;
DROP TABLE IF EXISTS users;

COMMIT;
```

## Index Strategy

**When to create an index:**
- Column used in `WHERE`, `JOIN ON`, `ORDER BY`, or `GROUP BY` on tables > 10k rows
- Foreign key columns (PostgreSQL does NOT auto-index FKs)
- Columns used in UNIQUE constraints (auto-indexed)
- Columns used in partial queries (use partial indexes)

**Index types:**
- `B-tree` (default): equality and range queries on most types
- `GIN`: full-text search, JSONB containment queries
- `GiST`: geometric data, fuzzy text search (pg_trgm)
- `BRIN`: time-series tables ordered by insertion (huge tables, sequential scans ok)

**Composite index rule:** Put the most selective column first; only add columns that appear together in queries.

```sql
-- Composite: queries filter by user_id AND status together
CREATE INDEX idx_orders_user_status ON orders (user_id, status);

-- Partial: only index active records (saves space, faster for common case)
CREATE INDEX idx_users_email_active ON users (email) WHERE deleted_at IS NULL;

-- GIN for JSONB
CREATE INDEX idx_products_metadata ON products USING GIN (metadata);
```

## Foreign Key Conventions

```sql
-- Always specify ON DELETE behavior explicitly — never leave implicit
user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,   -- deleting user deletes records
user_id UUID REFERENCES users(id) ON DELETE SET NULL,           -- orphan safe
user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,  -- prevent deletion if referenced
```

Always create an index on the FK column:
```sql
CREATE INDEX idx_orders_user_id ON orders (user_id);
```

## Soft Delete Pattern

```sql
-- Schema: every entity table has deleted_at
deleted_at TIMESTAMPTZ  -- NULL = active, non-null = deleted

-- Unique indexes must be partial to allow re-creation after soft delete:
CREATE UNIQUE INDEX idx_users_email ON users (email) WHERE deleted_at IS NULL;

-- Soft delete query:
UPDATE users SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL;

-- All SELECT queries must filter:
SELECT * FROM users WHERE deleted_at IS NULL AND id = $1;

-- Hard purge (for GDPR compliance, run periodically):
DELETE FROM users WHERE deleted_at < NOW() - INTERVAL '90 days';
```

## Audit Fields Convention

Every table must have:
```sql
created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
-- For user-facing entities:
created_by  UUID REFERENCES users(id) ON DELETE SET NULL,
updated_by  UUID REFERENCES users(id) ON DELETE SET NULL,
```

Attach the `update_updated_at_column` trigger to every table.

## Common Query Patterns (Parameterized)

```ts
// Repository pattern — always use parameterized queries, never string concatenation
import { Pool } from 'pg';

export class UserRepository {
  constructor(private readonly pool: Pool) {}

  async findById(id: string): Promise<User | null> {
    const result = await this.pool.query<User>(
      'SELECT * FROM users WHERE id = $1 AND deleted_at IS NULL',
      [id]
    );
    return result.rows[0] ?? null;
  }

  async findByEmail(email: string): Promise<User | null> {
    const result = await this.pool.query<User>(
      'SELECT * FROM users WHERE email = $1 AND deleted_at IS NULL',
      [email.toLowerCase().trim()]
    );
    return result.rows[0] ?? null;
  }

  async create(data: CreateUserDto): Promise<User> {
    const result = await this.pool.query<User>(
      `INSERT INTO users (email, password_hash, name, role)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [data.email, data.passwordHash, data.name, data.role ?? 'user']
    );
    return result.rows[0];
  }

  async findPaginated(page: number, limit: number): Promise<{ rows: User[]; total: number }> {
    const offset = (page - 1) * limit;
    const [dataResult, countResult] = await Promise.all([
      this.pool.query<User>(
        'SELECT * FROM users WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT $1 OFFSET $2',
        [limit, offset]
      ),
      this.pool.query<{ count: string }>(
        'SELECT COUNT(*) FROM users WHERE deleted_at IS NULL'
      ),
    ]);
    return { rows: dataResult.rows, total: parseInt(countResult.rows[0].count, 10) };
  }
}
```

## Redis Caching Pattern (Cache-Aside)

```ts
// utils/cache.ts
import { createClient } from 'redis';
import { logger } from '../config/logger';

const redis = createClient({ url: config.REDIS_URL });
await redis.connect();

// Cache key naming: <entity>:<id>[:<field>]
// Examples: user:abc123, user:abc123:permissions, product:list:page:1

export async function withCache<T>(
  key: string,
  ttlSeconds: number,
  fetchFn: () => Promise<T>
): Promise<T> {
  try {
    const cached = await redis.get(key);
    if (cached !== null) return JSON.parse(cached) as T;
  } catch (err) {
    logger.warn({ err, key }, 'Cache read failed, falling through to source');
  }

  const data = await fetchFn();

  try {
    await redis.setEx(key, ttlSeconds, JSON.stringify(data));
  } catch (err) {
    logger.warn({ err, key }, 'Cache write failed');
  }

  return data;
}

export async function invalidateCache(pattern: string): Promise<void> {
  const keys = await redis.keys(pattern);
  if (keys.length > 0) await redis.del(keys);
}

// Usage in service:
async function getUserById(id: string): Promise<User> {
  return withCache(`user:${id}`, 300, async () => {
    const user = await userRepository.findById(id);
    if (!user) throw AppError.notFound('User');
    return user;
  });
}
```

## Transaction Pattern

```ts
async function transferCredits(fromId: string, toId: string, amount: number): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      'UPDATE wallets SET balance = balance - $1 WHERE user_id = $2 AND balance >= $1',
      [amount, fromId]
    );
    // Check affected rows — if 0, insufficient balance
    await client.query(
      'UPDATE wallets SET balance = balance + $1 WHERE user_id = $2',
      [amount, toId]
    );
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
```
