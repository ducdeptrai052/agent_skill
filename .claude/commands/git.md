Generate a Conventional Commits commit message and a GitHub PR description for the described change.

@.claude/skills/git.md

$ARGUMENTS

Read the change description above and produce the following:

1. **Commit Message** — Single commit message following Conventional Commits spec:
   ```
   <type>(<scope>): <short description (max 72 chars)>

   <optional body: what changed and why, not how. Max 3 bullet points.>

   <optional footer: BREAKING CHANGE, Closes #issue>
   ```
   Valid types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `ci`, `build`
   Scope must be the feature area (e.g., `auth`, `user`, `payment`, `api`, `db`, `ci`)
   If it's a breaking change, add `!` after the type: `feat(auth)!: change token format`

2. **Alternative Commit Messages** — 2 alternatives if the first doesn't fit, ranked by preference.

3. **PR Title** — Same format as commit message but can be slightly longer (max 100 chars).

4. **PR Description** — Full GitHub PR body in Markdown:
   ```markdown
   ## Summary
   <!-- What does this PR do? 2-4 sentences. -->

   ## Changes
   - [ ] Change 1
   - [ ] Change 2

   ## Type of Change
   - [ ] Bug fix (non-breaking change that fixes an issue)
   - [ ] New feature (non-breaking change that adds functionality)
   - [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
   - [ ] Refactor (no functional changes)
   - [ ] Documentation update

   ## Testing
   <!-- How was this tested? What test cases were added? -->
   - [ ] Unit tests added/updated
   - [ ] Integration tests added/updated
   - [ ] Manual testing performed

   ## Checklist
   - [ ] Code follows project conventions (CLAUDE.md)
   - [ ] TypeScript strict mode — no `any`
   - [ ] No secrets committed
   - [ ] Tests pass locally
   - [ ] Migration files included (if DB changed)

   ## Screenshots (if UI change)
   <!-- Add before/after screenshots -->

   Closes #
   ```

5. **Branch Name Suggestion** — `<type>/<short-kebab-description>` e.g. `feat/add-refresh-token-rotation`

Rules:
- Commit message body must explain *why*, not *what* (the diff shows what).
- Never use vague descriptions like "update code" or "fix bug" — be specific.
- If the change touches multiple scopes, pick the primary one or use a broader scope.
- BREAKING CHANGE footer must describe what breaks and how to migrate.
