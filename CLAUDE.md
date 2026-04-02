# CLAUDE.md — Project Intelligence

## Tech Stack

| Layer      | Technology                                      |
|------------|-------------------------------------------------|
| Backend    | Node.js 20+, Express.js, TypeScript 5 (strict)  |
| Frontend   | React 18, Next.js 14 (App Router), Tailwind CSS |
| Database   | PostgreSQL 16, Redis 7                          |
| Infra      | VPS, Docker, Docker Compose, GitHub Actions     |
| AI         | Claude API (claude-sonnet-4-6), multi-agent     |

## Rules (Guardrails)

@.claude/rules/typescript.md
@.claude/rules/security.md
@.claude/rules/api.md
@.claude/rules/naming.md

## Skills

@.claude/skills/backend.md
@.claude/skills/frontend.md
@.claude/skills/database.md
@.claude/skills/docker.md
@.claude/skills/ai-agent.md
@.claude/skills/testing.md
@.claude/skills/git.md
@.claude/skills/seo-content.md

## Ground Rules

### TypeScript
- Always use `strict: true` in tsconfig. No `any` — use `unknown` then narrow.
- Prefer `interface` for object shapes, `type` for unions/intersections.
- All async functions must have explicit return types.
- Never use non-null assertion (`!`) without a comment explaining why it's safe.

### API Response Format
Every HTTP response MUST follow this shape:
```ts
type ApiResponse<T> = {
  data: T | null;
  error: { code: string; message: string; details?: unknown } | null;
  meta?: { page?: number; total?: number; took_ms?: number };
};
```
Success: `{ data: T, error: null }`. Failure: `{ data: null, error: {...} }`.

### Conventional Commits
All commits must follow: `<type>(<scope>): <description>`
Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `ci`
Example: `feat(auth): add refresh token rotation`

### Error Handling
- Always use the `AppError` class (defined in backend skill) for thrown errors.
- Never swallow errors silently — log then rethrow or respond.
- Async Express routes must be wrapped with `asyncHandler`.

### Code Style
- No default exports (use named exports everywhere).
- File names: `kebab-case.ts` for modules, `PascalCase.tsx` for components.
- Constants in `SCREAMING_SNAKE_CASE`.
- Max function length: 40 lines. If longer, extract helpers.
- No comments explaining *what* the code does — only *why* when non-obvious.

### Environment Variables
- Never hardcode secrets. All config via env vars validated with Zod at startup.
- Use `.env.example` as the source of truth for required vars.

## AI Teammates (Agents)

| Agent        | Trigger                              | What it does                                  |
|--------------|--------------------------------------|-----------------------------------------------|
| `reviewer`   | After editing any source file        | Catches bugs, security issues, violations      |
| `debugger`   | When given error/stack trace         | Root cause analysis + verified fix             |
| `tester`     | When given a source file path        | Generates complete Vitest + Supertest tests    |

Invoke with: `@reviewer`, `@debugger`, `@tester` in Claude Code chat.

## Hooks

| Hook            | Trigger                  | Action                              |
|-----------------|--------------------------|-------------------------------------|
| `post-edit.sh`  | After Claude edits a file | Auto-format with Prettier + ESLint  |
| `pre-commit.sh` | Before `git commit`      | TSC + ESLint + secrets scan + tests |
| `pre-push.sh`   | Before `git push`        | Full test suite + coverage + build  |

## Slash Commands

Use these commands by typing `/command-name <arguments>` in Claude Code:

| Command      | What it does                                              | Example usage                              |
|--------------|-----------------------------------------------------------|--------------------------------------------|
| `/review`    | Review a file for bugs, violations, suggestions          | `/review src/services/auth.service.ts`     |
| `/migration` | Generate SQL migration file (UP + DOWN)                  | `/migration add users email_verified bool` |
| `/deploy`    | Generate deploy checklist + Docker commands              | `/deploy prod`                             |
| `/test`      | Generate unit + integration tests for a file             | `/test src/controllers/user.controller.ts` |
| `/git`       | Generate commit message + PR description                 | `/git add rate limiting to API`            |
| `/seo`       | Generate meta/OG/schema.org tags                         | `/seo https://example.com/product/abc`     |
| `/agent`     | Plan a multi-agent task with tools and steps             | `/agent scrape and summarize competitor prices` |
