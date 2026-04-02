# Rule: Naming Conventions

Consistent naming reduces cognitive load. Follow these without exception.

## Files & Directories

| Type                    | Convention         | Example                          |
|-------------------------|--------------------|----------------------------------|
| TypeScript module       | `kebab-case.ts`    | `auth.service.ts`                |
| React component file    | `PascalCase.tsx`   | `UserCard.tsx`                   |
| Component folder        | `PascalCase/`      | `UserCard/`                      |
| Test file               | `*.test.ts`        | `auth.service.test.ts`           |
| Type definition file    | `*.types.ts`       | `user.types.ts`                  |
| Hook file               | `use*.ts`          | `useDebounce.ts`                 |
| Config file             | `*.config.ts`      | `vitest.config.ts`               |
| SQL migration           | `YYYYMMDD_*.sql`   | `20260402_create_users.sql`      |

## TypeScript Variables & Functions

```ts
// Variables and function parameters: camelCase
const userId = 'abc123';
const accessToken = signAccessToken({ userId, role });

// Functions: camelCase, verb-first
async function getUserById(id: string): Promise<User | null> { ... }
function validateEmailFormat(email: string): boolean { ... }
function buildQueryString(params: Record<string, string>): string { ... }

// Constants (module-level, never change): SCREAMING_SNAKE_CASE
const MAX_RETRY_ATTEMPTS = 3;
const DEFAULT_PAGE_SIZE = 20;
const JWT_ALGORITHM = 'HS256' as const;

// Enums: PascalCase type, SCREAMING_SNAKE_CASE members
enum UserRole {
  USER = 'USER',
  ADMIN = 'ADMIN',
  MODERATOR = 'MODERATOR',
}

// Interfaces: PascalCase, no "I" prefix
interface UserRepository { ... }   // ✓
interface IUserRepository { ... }  // ✗ — no "I" prefix

// Type aliases: PascalCase
type ApiResponse<T> = { data: T; error: null } | { data: null; error: ApiError };

// Generic type parameters: single uppercase letter or descriptive PascalCase
function wrap<T>(value: T): ApiResponse<T> { ... }
function transform<TInput, TOutput>(input: TInput): TOutput { ... }
```

## React Components

```tsx
// Component: PascalCase
export function UserCard({ user }: UserCardProps) { ... }
export function LoginForm() { ... }

// Props interface: ComponentName + "Props"
interface UserCardProps { user: User; onDelete?: (id: string) => void; }

// Event handlers: handle + EventName (onClick → handleClick)
const handleSubmit = (e: React.FormEvent) => { ... };
const handleDeleteClick = () => { ... };

// Boolean props: is/has/can/should prefix
interface ButtonProps {
  isLoading?: boolean;
  isDisabled?: boolean;
  hasError?: boolean;
  canEdit?: boolean;
}
```

## Database (PostgreSQL)

```sql
-- Tables: snake_case, plural
CREATE TABLE users (...);
CREATE TABLE blog_posts (...);
CREATE TABLE order_items (...);

-- Columns: snake_case
user_id, created_at, email_verified, password_hash

-- Indexes: idx_<table>_<columns>
CREATE INDEX idx_users_email ON users (email);
CREATE INDEX idx_orders_user_status ON orders (user_id, status);

-- Foreign keys: <referenced_table_singular>_id
user_id REFERENCES users(id)
order_id REFERENCES orders(id)
```

## API & HTTP

```
// Endpoints: kebab-case, plural nouns
GET  /api/v1/users
GET  /api/v1/blog-posts/:id
POST /api/v1/orders/:id/actions/cancel

// JSON response keys: camelCase (transform from snake_case DB columns)
{ "userId": "abc", "createdAt": "2026-04-02T..." }
```

## Git

```
// Branch: <type>/<kebab-description>
feat/add-oauth-login
fix/user-pagination-bug
chore/upgrade-node-20

// Commit: Conventional Commits
feat(auth): add refresh token rotation
fix(user): correct pagination offset
```

## Environment Variables

```
// .env keys: SCREAMING_SNAKE_CASE
DATABASE_URL=...
JWT_SECRET=...
REDIS_URL=...
CORS_ORIGIN=...
```

## React Query Keys

```ts
// Query key factories: camelCase object with descriptive method names
export const userKeys = {
  all: ['users'] as const,
  lists: () => [...userKeys.all, 'list'] as const,
  list: (filters: object) => [...userKeys.lists(), filters] as const,
  detail: (id: string) => [...userKeys.all, 'detail', id] as const,
};
```
