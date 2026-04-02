# Git Skill — Branching, Conventional Commits, PR Workflow, Gitflow

## Branch Naming Convention

```
<type>/<short-kebab-description>

feat/add-refresh-token-rotation
fix/user-pagination-off-by-one
chore/upgrade-node-20
hotfix/critical-auth-bypass
release/v1.2.0
refactor/extract-payment-service
test/add-user-service-coverage
docs/update-api-readme
```

Rules:
- Max 50 chars for the description part
- Use lowercase + hyphens only — no underscores, no camelCase
- Include ticket number if applicable: `feat/PROJ-123-add-oauth-login`
- `hotfix/` branches cut from `main` (production), not `develop`
- `release/` branches cut from `develop`, merged into both `main` and `develop`

## Conventional Commits Format

```
<type>(<scope>): <short description>
│      │          └── Imperative mood. Max 72 chars. No period at end.
│      └── Optional. Feature area: auth, user, payment, db, ci, api, frontend
└── Required. One of the types below.

[optional body]
Explain *why* this change was made. Wrap at 72 chars.
Bullet points are ok.

[optional footer(s)]
BREAKING CHANGE: <description>
Closes #123
Refs #456
```

**Types:**
| Type       | When to use                                                   |
|------------|---------------------------------------------------------------|
| `feat`     | New feature visible to users                                  |
| `fix`      | Bug fix                                                        |
| `chore`    | Maintenance, dependency updates, no production code change    |
| `docs`     | Documentation only                                            |
| `refactor` | Code change that neither fixes a bug nor adds a feature       |
| `test`     | Adding or updating tests only                                 |
| `perf`     | Performance improvement                                       |
| `ci`       | CI/CD config changes                                          |
| `build`    | Build system changes (Dockerfile, webpack, etc.)              |

**Examples:**
```
feat(auth): add refresh token rotation

Previously refresh tokens were static. This introduces one-time-use
refresh tokens with rotation to prevent token replay attacks.

Closes #88

---

fix(user): correct pagination offset calculation

The offset was (page * limit) instead of ((page - 1) * limit),
causing page 1 and page 2 to return overlapping results.

Closes #102

---

feat(payment)!: change payment webhook payload structure

BREAKING CHANGE: The `amount` field is now in cents (integer) instead
of a decimal string. All consumers of POST /webhooks/payment must update
their parsers.

Migration: multiply existing decimal values by 100.

---

chore(deps): upgrade express from 4.18 to 4.21

Security patches for CVE-2024-XXXX. No API changes.
```

## PR Description Template

```markdown
## Summary
<!-- What does this PR do? 2-4 sentences. Focus on the "why" and business impact. -->

## Changes
- [ ] What changed in detail (bullet per logical change)
- [ ] Database migrations included: `20260402_add_users_email_verified.sql`
- [ ] Environment variables added/changed: `JWT_REFRESH_SECRET`

## Type of Change
- [ ] Bug fix (non-breaking)
- [ ] New feature (non-breaking)
- [ ] Breaking change — consumers must update
- [ ] Refactor (no functional changes)
- [ ] Performance improvement
- [ ] CI/infrastructure change

## How to Test
1. Step-by-step instructions to verify this works
2. Include example API calls with curl or Postman collection

## Checklist
- [ ] TypeScript strict — no `any`
- [ ] Tests added/updated — coverage not reduced
- [ ] No secrets or sensitive data in code
- [ ] DB migrations have UP + DOWN
- [ ] Breaking changes documented in BREAKING_CHANGES.md
- [ ] Self-reviewed the diff

Closes #
```

## Merge Strategy

| Branch type       | Merge strategy | Why                                                |
|-------------------|----------------|----------------------------------------------------|
| `feat/*` → develop  | Squash merge   | Clean history, one commit per feature              |
| `fix/*` → develop   | Squash merge   | Same — clean logical unit                          |
| `hotfix/*` → main   | Merge commit   | Preserve hotfix history for auditability           |
| `release/*` → main  | Merge commit   | Preserve release commit for `git tag` traceability |
| `release/*` → develop | Merge commit | Keep develop in sync                               |

**Never** force-push `main` or `develop`. Use `git revert` for undos on protected branches.

## Gitflow Summary

```
main ──────────────────────────────────────── (production, always deployable)
   │                        ↑ merge + tag v1.1.0
develop ──────────────────release/v1.1.0──── (integration branch)
   │    ↑ squash       ↑ cut from develop
feat/login    fix/bug-xyz
```

1. All features branch from `develop`
2. PRs merge (squash) back to `develop` after review + CI pass
3. When ready to release: cut `release/vX.Y.Z` from `develop`
4. Only bug fixes go onto the release branch
5. Merge release into `main` (merge commit) + tag `vX.Y.Z`
6. Merge release back into `develop` to capture any release-phase fixes
7. Hotfixes branch from `main`, merge into both `main` and `develop`

## Git Hooks with Husky

```json
// package.json
{
  "scripts": {
    "prepare": "husky"
  }
}
```

```bash
# .husky/pre-commit
#!/bin/sh
echo "Running pre-commit checks..."
npx lint-staged
```

```bash
# .husky/commit-msg
#!/bin/sh
npx --no -- commitlint --edit "$1"
```

```js
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'scope-enum': [2, 'always', ['auth', 'user', 'payment', 'api', 'db', 'ci', 'frontend', 'infra', 'deps']],
    'subject-max-length': [2, 'always', 72],
  },
};
```

```json
// .lintstagedrc
{
  "*.{ts,tsx}": ["eslint --fix", "prettier --write"],
  "*.{json,md,yml,yaml}": ["prettier --write"],
  "*.ts": ["bash -c 'tsc --noEmit'"]
}
```
