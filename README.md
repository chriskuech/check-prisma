# Check Prisma Migrations GitHub Action

This GitHub Action validates Prisma migrations in pull requests by:

1. Starting a PostgreSQL database (with pgvector)
2. Checking out the base branch and applying its existing migrations
3. Checking out the PR branch, analyzing the risk of its new migrations with
   [pgfence](https://www.npmjs.com/package/@flvmnt/pgfence), and applying them
4. Verifying there are no pending schema changes

## Inputs

| Name           | Description                                                                                                             | Required | Default |
| -------------- | ------------------------------------------------------------------------------------------------------------------------- | -------- | ------- |
| `path`         | Path to the npm project root, relative to the repository root. Must contain `package.json` and `prisma/schema.prisma`. | No       | `.`     |
| `node-version` | Node.js version to use.                                                                                                   | No       | `22`    |
| `max-risk`     | Maximum migration risk level allowed by pgfence. One of: `low`, `medium`, `high`, `critical`.                            | No       | `low`   |
| `base-ref`     | Git ref to check out as the base branch, instead of the pull request's base commit. Mainly for testing this action itself; most callers should leave this unset. | No       | (PR base commit) |
| `head-ref`     | Git ref to check out as the PR branch, instead of the pull request's head commit. Mainly for testing this action itself; most callers should leave this unset. | No       | (PR head commit) |

## Usage

Add this workflow to your repository at `.github/workflows/check-prisma.yml`:

```yaml
name: Check Prisma Migrations

on:
  pull_request:
    branches:
      - main
    paths:
      - prisma/**
      - ".github/workflows/check-prisma.yml"

permissions:
  contents: read

jobs:
  check-migrations:
    runs-on: ubuntu-latest
    steps:
      - uses: kuech/check-prisma@v1
        with:
          path: . # optional; defaults to "."
          max-risk: low # optional; one of low, medium, high, critical
```

For a monorepo with the Prisma project in a subdirectory:

```yaml
      - uses: kuech/check-prisma@v1
        with:
          path: packages/db
```

## Prisma version support

Supports Prisma >= 6, including both the classic `package.json`-based
config and the `prisma.config.ts` config Prisma 7 requires. The CLI flags
for detecting pending schema changes differ between major versions (Prisma
7 removed `--from-schema-datasource`/`--to-schema-datamodel` in favor of
`--from-config-datasource`/`--to-schema`); the action detects the installed
version and uses the right ones -- see `scripts/check-schema-drift.sh`.

## Development

The action's logic lives in `scripts/*.sh`, called from `action.yml`. See
[`test/README.md`](test/README.md) for the functional test suite, which
invokes the action itself (`uses: ./`) against real, pushed fixture
branches, a real Postgres database, and a real Prisma CLI -- covering valid
migrations, pgfence risk, schema drift, a broken migration, and a broken
seed script, for every supported Prisma major version.
