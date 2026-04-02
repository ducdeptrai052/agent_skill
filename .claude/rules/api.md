# Rule: API Design Conventions

All HTTP APIs in this project must follow these conventions without exception.

## Response Shape

Every response — success or error — must use this exact envelope:
```ts
// Success
{ "data": <payload>, "error": null }
{ "data": <payload>, "error": null, "meta": { "page": 1, "total": 50, "limit": 20 } }

// Error
{ "data": null, "error": { "code": "NOT_FOUND", "message": "User not found" } }
{ "data": null, "error": { "code": "VALIDATION_ERROR", "message": "Invalid input", "details": { ... } } }
```

Use the `sendSuccess()` and `sendPaginated()` helpers — never write `res.json()` manually.

## HTTP Status Codes

| Situation                          | Status | Error code           |
|------------------------------------|--------|----------------------|
| Success, resource returned         | 200    | —                    |
| Resource created                   | 201    | —                    |
| Success, no content                | 204    | —                    |
| Validation error (bad input)       | 400    | `VALIDATION_ERROR`   |
| Missing/invalid auth token         | 401    | `UNAUTHORIZED`       |
| Valid token, insufficient permission | 403  | `FORBIDDEN`          |
| Resource not found                 | 404    | `NOT_FOUND`          |
| Unique constraint violation        | 409    | `CONFLICT`           |
| Payload too large                  | 413    | `PAYLOAD_TOO_LARGE`  |
| Rate limit exceeded                | 429    | `RATE_LIMITED`       |
| Unhandled server error             | 500    | `INTERNAL_ERROR`     |

## URL Structure

```
/api/v1/<resource>                  GET (list), POST (create)
/api/v1/<resource>/:id              GET (single), PATCH (update), DELETE (remove)
/api/v1/<resource>/:id/<sub>        Nested resource
/api/v1/<resource>/:id/actions/<action>  Non-CRUD actions (e.g., /users/:id/actions/ban)
```

Rules:
- Plural nouns: `/users`, `/products`, `/orders` — never `/user`, `/getUser`
- Lowercase + hyphens: `/blog-posts` not `/blogPosts`
- Version prefix: always `/api/v1/` — increment version only for breaking changes
- No verbs in URLs: `/orders/:id/actions/cancel` not `/cancel-order/:id`

## Pagination

All list endpoints must support pagination:
```ts
// Query params
GET /api/v1/users?page=1&limit=20&sort=created_at&order=desc&search=john

// Response
{
  "data": [...],
  "error": null,
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "pages": 8
  }
}
```

Default `limit`: 20. Maximum `limit`: 100. Reject requests with `limit > 100`.

## Request Body

- Use `PATCH` for partial updates (not `PUT` — we don't require full replacement)
- Body must be JSON: `Content-Type: application/json`
- Validate body with Zod schema before any processing
- Strip unknown fields: `schema.strict()` or strip with `.strip()`

## Error Codes

Error `code` must be a `SCREAMING_SNAKE_CASE` string. Use these standard codes:

```ts
export const ErrorCodes = {
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  UNAUTHORIZED: 'UNAUTHORIZED',
  FORBIDDEN: 'FORBIDDEN',
  NOT_FOUND: 'NOT_FOUND',
  CONFLICT: 'CONFLICT',
  RATE_LIMITED: 'RATE_LIMITED',
  INTERNAL_ERROR: 'INTERNAL_ERROR',
  // Domain-specific:
  INVALID_CREDENTIALS: 'INVALID_CREDENTIALS',
  EMAIL_NOT_VERIFIED: 'EMAIL_NOT_VERIFIED',
  INSUFFICIENT_CREDITS: 'INSUFFICIENT_CREDITS',
} as const;
```

Never expose internal error messages to clients (stack traces, SQL errors, file paths).

## Authentication

- Access token: `Authorization: Bearer <token>` header
- Refresh token: `refresh_token` httpOnly cookie
- Public endpoints: no auth header required
- Protected endpoints: `requireAuth` middleware must be present
- Admin endpoints: `requireAuth` + `requireRole('admin')` middlewares

## Versioning

When a breaking change is required:
1. Add `/api/v2/` route alongside `/api/v1/`
2. Maintain v1 for at least 3 months with deprecation notice header: `Deprecation: true`
3. Document migration in `BREAKING_CHANGES.md`
