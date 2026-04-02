Review the given file for bugs, convention violations, and improvement opportunities.

@.claude/skills/backend.md
@.claude/skills/frontend.md
@.claude/skills/testing.md
@.claude/skills/git.md

$ARGUMENTS

Perform a thorough code review of the file path provided above. Output must be structured as:

1. **File Summary** — One paragraph describing what this file does and its role in the project.

2. **Bugs** — Numbered list. Each item must include:
   - Line number(s) affected
   - Description of the bug
   - Why it's a bug (runtime error, incorrect logic, security risk, etc.)
   - Fixed code snippet in TypeScript

3. **Convention Violations** — Numbered list. Each item must include:
   - Line number(s) affected
   - Which convention is violated (reference CLAUDE.md ground rules or skill files)
   - Corrected code snippet

4. **Security Issues** — Numbered list. Flag: SQL injection, XSS, missing auth checks, secrets in code, insecure deserialization, missing rate limiting. If none, write "None found."

5. **Performance Issues** — Numbered list. Flag: N+1 queries, missing indexes hint, synchronous blocking calls, large payload without pagination. If none, write "None found."

6. **Suggestions** — Numbered list of non-critical improvements. Each must include a before/after code snippet. Maximum 5 suggestions — prioritize highest impact.

7. **Overall Score** — Rate the file: PASS / NEEDS WORK / FAIL, with one sentence justification.

Rules:
- Be specific. Never write vague feedback like "improve error handling" without showing the fix.
- All code snippets must be valid TypeScript matching the project's strict mode.
- Do not suggest changes outside the scope of what the file is responsible for.
- If the file path does not exist or is unreadable, say so and stop.
