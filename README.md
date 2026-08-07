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
