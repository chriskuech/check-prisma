# Functional tests

`.github/workflows/test.yml` exercises the actual composite action
(`uses: ./`) against a real Postgres database and a real Prisma CLI -- no
mocking, and no reimplementation of the action's steps. It covers the main
ways a PR's migrations can be wrong, plus the happy path, across every
Prisma major version >= 6 the action supports.

## How it works

For each `(scenario, prisma-version)` combination in the `functional` job's
matrix:

1. `test/lib/push-fixture-branch.sh` assembles that scenario's `base` and
   `head` fixtures (see below) into two throwaway branches and force-pushes
   them to this repository.
2. The action is invoked with `base-ref`/`head-ref` pointing at those two
   commits -- the same inputs a real pull request supplies, just aimed at
   fixture branches instead of a PR's actual base/head. The action's own
   `actions/checkout` steps, Postgres container, and `scripts/*.sh` all run
   exactly as they would for a real PR.
3. The step is expected to fail for some scenarios, so its outcome is
   captured (`continue-on-error: true`) and compared against what the
   scenario expects, rather than just asserting the job is green.
4. The fixture branches are deleted, whether or not the run succeeded.

## Scenarios

| Scenario                 | Action run is expected to |
| ------------------------- | -------------------------- |
| `valid`                    | succeed |
| `pgfence-risk`              | fail (pgfence flags the PR's migration) |
| `schema-drift`               | fail (schema.prisma has a change no migration covers) |
| `invalid-migration-sql`      | fail (the PR's latest migration SQL errors when applied) |
| `bad-seed`                     | fail (the base branch's seed script errors) |

Each scenario is a `base`/`head` pair of fixture directories under
`test/fixtures/scenarios/`, mirroring the base and PR branch states a real
pull request would present. `test/lib/assemble-project.sh` combines a
scenario fixture with a Prisma-version fixture from
`test/fixtures/versions/{6,7}/` (package.json, and for Prisma 7,
prisma.config.ts) into a runnable npm project.

## Adding a Prisma version

Add a directory under `test/fixtures/versions/<major>/` with a
`package.json` pinning that major (e.g. `"prisma": "^8.0.0"`), a
`schema-header.prisma` fragment (the `generator`/`datasource` block), and,
if that version requires it, a `prisma.config.ts`. Then add the version to
the `prisma-version` matrix in `.github/workflows/test.yml`.

## Local sanity checks (faster, but don't exercise action.yml)

`test/run-scenario.sh` and `test/run-all.sh` run `scripts/*.sh` directly
against an assembled fixture, skipping `action.yml` and its
`actions/checkout` steps entirely. They're useful for quickly iterating on
`scripts/*.sh` or a fixture without pushing branches or spinning up a
GitHub Actions job, but a green run from them is not sufficient evidence
the action itself works -- only `.github/workflows/test.yml` (or a real PR)
actually calls it. Requires a disposable Postgres reachable at
`DATABASE_URL` (`postgresql://postgres:postgres@localhost:5432/test` by
default):

```sh
docker run -d --name check-prisma-test-postgres \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=test \
  -p 5432:5432 pgvector/pgvector:pg17

bash test/run-all.sh 6
bash test/run-all.sh 7
bash test/run-scenario.sh schema-drift 7
```

`run-scenario.sh`/`run-all.sh` call `prisma migrate reset --force` against
whatever `DATABASE_URL` points at -- always run them against a disposable
database, never a real one.
