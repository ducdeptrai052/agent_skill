# Rule: TypeScript Strictness

These rules are non-negotiable. Apply them in every TypeScript file you write or edit.

## Forbidden Patterns

### No `any` type
```ts
// ✗ NEVER
function process(data: any) { ... }
const result: any = await fetch(...);

// ✓ Use unknown + narrowing
function process(data: unknown) {
  if (typeof data === 'string') { ... }
}

// ✓ Or define the interface
interface ProcessInput { id: string; value: number; }
function process(data: ProcessInput) { ... }
```

### No non-null assertion without justification
```ts
// ✗ Lazy
const name = user!.profile!.name;

// ✓ Narrow explicitly
if (!user?.profile?.name) throw AppError.badRequest('Missing profile name');
const name = user.profile.name;

// ✓ Acceptable with comment explaining invariant
const token = req.headers.authorization!; // guaranteed by requireAuth middleware above
```

### No `as` casting to bypass type safety
```ts
// ✗ Silences the compiler, doesn't fix the type
const user = data as User;

// ✓ Validate the shape at runtime, then TypeScript knows
const parsed = userSchema.parse(data); // Zod validates AND narrows
```

### No implicit `any` from untyped JSON
```ts
// ✗
const body = JSON.parse(rawString); // body is `any`

// ✓
const body: unknown = JSON.parse(rawString);
const validated = createUserSchema.parse(body); // now it's typed
```

## Required Patterns

### Explicit return types on all async functions
```ts
// ✗
async function getUserById(id: string) { ... }

// ✓
async function getUserById(id: string): Promise<User | null> { ... }
```

### Prefer `interface` for object shapes, `type` for unions
```ts
// ✓
interface User { id: string; email: string; role: Role; }
type Role = 'user' | 'admin' | 'moderator';
type ApiResponse<T> = { data: T; error: null } | { data: null; error: ApiError };
```

### Exhaustive switch on union types
```ts
type Status = 'pending' | 'active' | 'banned';

function getLabel(status: Status): string {
  switch (status) {
    case 'pending': return 'Pending Review';
    case 'active': return 'Active';
    case 'banned': return 'Banned';
    default: {
      const _exhaustive: never = status; // compile error if new status added
      throw new Error(`Unhandled status: ${_exhaustive}`);
    }
  }
}
```

### Readonly for function parameters that shouldn't mutate
```ts
function processUsers(users: readonly User[]): Summary { ... }
```

### Zod for all external data boundaries
Validate at: HTTP request body, query params, env vars, API responses, JSON.parse results.
```ts
const createUserSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(128),
  name: z.string().min(1).max(100),
});
type CreateUserDto = z.infer<typeof createUserSchema>;
```

## tsconfig.json Requirements
```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true
  }
}
```
