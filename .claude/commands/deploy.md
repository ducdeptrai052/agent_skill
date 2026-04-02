Generate a deployment checklist and Docker commands for the specified environment.

@.claude/skills/docker.md
@.claude/skills/database.md

$ARGUMENTS

The argument is the target environment: `dev`, `staging`, or `prod`. Generate the following:

1. **Pre-Deploy Checklist** — Numbered list of tasks to complete BEFORE deploying:
   - [ ] All tests passing in CI
   - [ ] Environment-specific `.env` values confirmed
   - [ ] Database migrations reviewed and tested on staging first
   - [ ] Docker image built and tagged correctly
   - [ ] Secrets rotated if this deploy includes auth changes
   - [ ] Rollback plan documented
   - Add environment-specific items (prod: extra caution items, dev: minimal)

2. **Docker Build Commands** — Exact shell commands to build and tag the image:
   ```bash
   # Build
   docker build --target production -t myapp:<env>-<YYYYMMDD> .

   # Tag latest
   docker tag myapp:<env>-<YYYYMMDD> myapp:<env>-latest

   # Push to registry (if applicable)
   docker push registry.example.com/myapp:<env>-<YYYYMMDD>
   ```

3. **Deploy Commands** — Exact commands to bring up the stack:
   ```bash
   # For dev
   docker compose -f docker-compose.yml up -d

   # For staging/prod
   docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --no-build
   ```

4. **Database Migration Command** — Command to run pending migrations inside the container:
   ```bash
   docker compose exec api node dist/db/migrate.js up
   ```

5. **Health Check Verification** — Commands to verify the deployment is healthy:
   ```bash
   # Check container status
   docker compose ps

   # Check API health endpoint
   curl -f http://localhost:3000/health

   # Check logs for errors
   docker compose logs --tail=50 api
   ```

6. **Rollback Procedure** — Step-by-step commands to roll back if something goes wrong:
   - Roll back Docker image to previous tag
   - Roll back database migration (DOWN)
   - Restart containers

7. **Post-Deploy Checklist** — Numbered list:
   - [ ] Health endpoint returning 200
   - [ ] Key user flows smoke tested
   - [ ] Error rate in logs normal
   - [ ] Response times acceptable
   - [ ] Notify team in Slack/Discord

Rules:
- For `prod` environment: add a confirmation prompt reminder ("Have you run this on staging first?").
- All commands must be copy-pasteable with no placeholders left unfilled (use `myapp` as default app name).
- Never suggest `docker compose down` in a prod deploy — use rolling restart instead.
