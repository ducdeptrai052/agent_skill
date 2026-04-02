Generate a PostgreSQL migration file with UP and DOWN sections based on the described schema change.

@.claude/skills/database.md

$ARGUMENTS

Read the database change description above and produce a complete migration. Output must be structured as:

1. **Migration Filename** — Format: `YYYYMMDD_<snake_case_description>.sql` using today's date. Example: `20260402_add_users_email_verified.sql`

2. **Full Migration File Content** — The complete `.sql` file wrapped in a code block:
   ```sql
   -- Migration: <filename>
   -- Description: <one line description>
   -- Author: generated
   -- Date: <YYYY-MM-DD>

   -- ============================================================
   -- UP
   -- ============================================================
   BEGIN;

   <UP SQL statements here>

   COMMIT;

   -- ============================================================
   -- DOWN
   -- ============================================================
   BEGIN;

   <DOWN SQL statements that fully reverse the UP migration>

   COMMIT;
   ```

3. **Index Recommendations** — List any indexes that should accompany this migration. For each:
   - Column(s) to index
   - Index type (B-tree, GIN, etc.)
   - Reason (query pattern it supports)
   - SQL to create it (include in UP, drop in DOWN)

4. **Rollback Safety Check** — One paragraph: is this migration safely reversible? Flag any destructive operations (DROP COLUMN, DROP TABLE, NOT NULL without default) and how to mitigate.

5. **Estimated Impact** — Brief note on table size impact, locking behavior (does this require `ACCESS EXCLUSIVE` lock?), and whether this should run during off-peak hours.

Rules:
- Always wrap statements in `BEGIN; ... COMMIT;` transactions.
- Use `IF NOT EXISTS` / `IF EXISTS` guards where appropriate.
- DOWN migration must fully reverse everything in UP — no partial rollbacks.
- Use `snake_case` for all table and column names.
- Include `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()` and `updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()` for new tables.
- Add `deleted_at TIMESTAMPTZ` for any entity table (soft delete pattern).
- Foreign keys must have explicit `ON DELETE` behavior stated.
