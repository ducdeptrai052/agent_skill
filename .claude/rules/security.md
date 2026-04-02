# Rule: Security Guardrails

Every line of code must pass these checks. These are not suggestions.

## Input Validation

**All user input must be validated with Zod before use.**
```ts
// ✗ Trust req.body directly
app.post('/users', async (req, res) => {
  await db.query('INSERT INTO users...', [req.body.email]);
});

// ✓ Validate first
const schema = z.object({ email: z.string().email() });
app.post('/users', async (req, res) => {
  const { email } = schema.parse(req.body); // throws ZodError if invalid
  await db.query('INSERT INTO users (email) VALUES ($1)', [email]);
});
```

**Validate query params too:**
```ts
const querySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  search: z.string().max(100).optional(),
});
const { page, limit, search } = querySchema.parse(req.query);
```

## SQL Injection Prevention

**Always use parameterized queries. Never concatenate strings into SQL.**
```ts
// ✗ SQL INJECTION VULNERABILITY
const rows = await pool.query(`SELECT * FROM users WHERE email = '${email}'`);

// ✓ Parameterized
const rows = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
```

If using a query builder, ensure parameters are always bound, never interpolated.

## Authentication & Authorization

**Every protected route MUST have `requireAuth` middleware.**
```ts
// ✗ Missing auth check
router.delete('/users/:id', asyncHandler(deleteUser));

// ✓
router.delete('/users/:id', requireAuth, requireRole('admin'), asyncHandler(deleteUser));
```

**Never trust client-provided user IDs for ownership checks.**
```ts
// ✗ User can delete anyone's post by changing the ID
const postId = req.params.id;
await postRepo.delete(postId);

// ✓ Scope to authenticated user
const postId = req.params.id;
const userId = req.user.userId; // from verified JWT
await postRepo.deleteByIdAndOwner(postId, userId); // SQL: WHERE id=$1 AND user_id=$2
```

## Secrets Management

**Never hardcode secrets. Never log secrets.**
```ts
// ✗
const jwtSecret = 'my-super-secret-key-hardcoded';

// ✗ Logging sensitive data
logger.info({ user, password: req.body.password }, 'Login attempt');

// ✓ Env vars validated at startup (see env.ts)
const { JWT_SECRET } = config;

// ✓ Redact sensitive fields in logger config
redact: ['req.headers.authorization', 'body.password', 'body.token', '*.secret']
```

**Never commit `.env` files.** `.env` must be in `.gitignore`.

## XSS Prevention

**Never render user-controlled content as raw HTML.**
```tsx
// ✗ XSS vulnerability
<div dangerouslySetInnerHTML={{ __html: userContent }} />

// ✓ Sanitize before rendering if HTML is required
import DOMPurify from 'dompurify';
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userContent) }} />

// ✓ Prefer plain text rendering
<p>{userContent}</p>
```

## Rate Limiting

**All public API endpoints must be rate limited.**
```ts
// Global rate limit (see app.ts middleware order)
app.use(rateLimit({ windowMs: 15 * 60 * 1000, max: 100 }));

// Stricter limits on auth endpoints
const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 10 });
router.post('/auth/login', authLimiter, asyncHandler(login));
router.post('/auth/register', authLimiter, asyncHandler(register));
```

## CORS

**Never use `origin: '*'` in production with credentials.**
```ts
// ✗
app.use(cors({ origin: '*', credentials: true })); // credentials + wildcard = browser blocks it AND security risk

// ✓
app.use(cors({
  origin: config.CORS_ORIGIN, // exact domain from env
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
}));
```

## File Upload Security

```ts
// ✗ Accept any file
app.post('/upload', upload.single('file'), handler);

// ✓ Validate type, size, extension
const upload = multer({
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB max
  fileFilter: (_req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp'];
    cb(null, allowed.includes(file.mimetype));
  },
});
// NEVER use the original filename — generate a UUID-based name
const filename = `${crypto.randomUUID()}.${ext}`;
```

## Dependency Security

- Run `npm audit` in CI. Fail on `high` or `critical` vulnerabilities.
- Pin major versions in `package.json` — no `*` or `latest`.
- Review `npm install <package>` before running — check the package on npmjs.com.
