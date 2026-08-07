# Functional tests

These tests exercise the actual logic the action runs (`scripts/*.sh`)
against a real, disposable Postgres database and a real Prisma CLI --
no mocking. They cover the main ways a PR's migrations can be wrong, plus
the happy path, across every Prisma major version >= 6 the action supports.

## Scenarios (`test/run-scenario.sh`)

| Scenario                 | Expected to fail at |
| ------------------------- | -------------------- |
| `valid`                    | (nothing -- full pipeline succeeds) |
| `pgfence-risk`              | `analyze-risk` (pgfence flags the PR's migration) |
| `schema-drift`               | `check-schema-drift` (schema.prisma has a change no migration covers) |
| `invalid-migration-sql`      | `deploy-migrations` (the PR's latest migration SQL errors when applied) |
| `bad-seed`                     | `reset-database` (the base branch's seed script errors) |

Each scenario is defined by a `base`/`head` pair of fixture directories
under `test/fixtures/scenarios/`, mirroring the base and PR branch states a
real pull request would present. `test/lib/assemble-project.sh` combines a
scenario fixture with a Prisma-version fixture from
`test/fixtures/versions/{6,7}/` (package.json, and for Prisma 7,
prisma.config.ts) into a throwaway npm project, then `run-scenario.sh` runs
`scripts/reset-database.sh` -> `scripts/analyze-risk.sh` ->
`scripts/deploy-migrations.sh` -> `scripts/check-schema-drift.sh` against
it in the same order the composite action does, stopping at the step each
scenario expects to fail (a real PR check would stop there too).

## Running locally

Requires a disposable Postgres reachable at `DATABASE_URL`
(`postgresql://postgres:postgres@localhost:5432/test` by default), e.g.:

```sh
docker run -d --name check-prisma-test-postgres \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=test \
  -p 5432:5432 pgvector/pgvector:pg17

# All 5 scenarios against one Prisma major version:
bash test/run-all.sh 6
bash test/run-all.sh 7

# A single scenario:
bash test/run-scenario.sh schema-drift 7
```

`run-scenario.sh` and `run-all.sh` call `prisma migrate reset --force`
against whatever `DATABASE_URL` points at -- always run them against a
disposable database, never a real one.

## Adding a Prisma version

Add a directory under `test/fixtures/versions/<major>/` with a
`package.json` pinning that major (e.g. `"prisma": "^8.0.0"`), a
`schema-header.prisma` fragment (the `generator`/`datasource` block), and,
if that version requires it, a `prisma.config.ts`. Then add the version to
the `prisma-version` matrix in `.github/workflows/test.yml`.
