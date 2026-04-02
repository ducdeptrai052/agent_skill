Generate unit tests and integration tests for the given file.

@.claude/skills/testing.md
@.claude/skills/backend.md
@.claude/skills/frontend.md

$ARGUMENTS

Read the source file at the path provided and generate comprehensive tests. Output must be structured as:

1. **Test File Location** — Where the test file should be saved, following the convention:
   - Unit test: `src/<same-path>/<filename>.test.ts`
   - Integration test: `tests/integration/<feature>.test.ts`

2. **Unit Tests** — Complete test file content using Vitest:
   ```ts
   import { describe, it, expect, beforeEach, vi } from 'vitest';
   // ... imports from source file

   describe('<ModuleName>', () => {
     // All functions/methods covered
     // Happy path + edge cases + error cases
   });
   ```
   Requirements:
   - Every exported function must have at least one `describe` block
   - Each `describe` block must cover: happy path, edge case, error/rejection case
   - Use `vi.mock` for external dependencies (database, Redis, external APIs)
   - Use factory functions for test data (no hardcoded magic values except for assertion clarity)
   - Mock time with `vi.useFakeTimers()` when testing time-sensitive logic

3. **Integration Tests** (only if the file is a controller or route handler):
   ```ts
   import { describe, it, expect, beforeAll, afterAll } from 'vitest';
   import request from 'supertest';
   import { app } from '../../src/app';

   describe('POST /api/v1/<resource>', () => {
     // Full HTTP round-trip tests
     // Test auth middleware behavior
     // Test validation rejection
     // Test success response shape matches { data, error, meta }
   });
   ```

4. **Mock Definitions** — List every mock needed and why:
   - Module path
   - What to mock (function/class/constant)
   - Default mock return value

5. **Coverage Estimate** — Which branches are covered, which are skipped and why.

Rules:
- Tests must be deterministic — no `Math.random()`, no real network calls, no real database calls in unit tests.
- All test data must match the TypeScript types from the source file.
- Integration tests ARE allowed to hit a test database (seeded fixtures).
- If the source file has no testable logic (e.g., it's a pure type definition file), say so and skip.
- Generate tests that would actually catch real bugs, not just assert that functions exist.
