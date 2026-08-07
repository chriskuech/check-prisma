#!/usr/bin/env bash
# Fails if the applied migrations don't produce the same database state that
# prisma/schema.prisma declares -- i.e. the PR is missing a migration for
# some schema change. Run from the npm project root with DATABASE_URL (and
# DIRECT_DATABASE_URL, where applicable) already exported.
set -euo pipefail

# The `prisma migrate diff` flags for "live database" vs. "schema's declared
# datamodel" changed across major versions:
#
#   - Prisma 6: the datasource URL still lives in schema.prisma, so the live
#     database is read via `--from-schema-datasource`, and the datamodel via
#     `--to-schema-datamodel`.
#   - Prisma 7: schema.prisma can no longer embed a datasource URL (it must
#     live in prisma.config.ts), so the live database is read via
#     `--from-config-datasource`, and the datamodel via the renamed
#     `--to-schema`. `--from-schema-datasource`/`--to-schema-datamodel` were
#     removed outright.
#
# Detect the installed major version so this works across both.
prisma_major="$(node -p "require('prisma/package.json').version.split('.')[0]")"

if [ "$prisma_major" -ge 7 ]; then
  npx prisma migrate diff \
    --from-config-datasource \
    --to-schema prisma/schema.prisma \
    --exit-code
else
  npx prisma migrate diff \
    --from-schema-datasource prisma/schema.prisma \
    --to-schema-datamodel prisma/schema.prisma \
    --exit-code
fi
