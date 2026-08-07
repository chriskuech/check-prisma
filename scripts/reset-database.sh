#!/usr/bin/env bash
# Applies the base branch's migrations to a fresh database, then seeds it.
# Run from the npm project root with DATABASE_URL (and, for schemas that
# declare one, DIRECT_DATABASE_URL) already exported.
set -euo pipefail

# Prisma 7 removed automatic seeding from `migrate reset` (and
# `migrate dev`) -- seeding must now be triggered explicitly via
# `prisma db seed`. Prisma 6 still seeds automatically as part of
# `migrate reset --force`. To get consistent, always-exercised seeding
# across both, skip the automatic seed on 6 (via --skip-seed, a flag 7
# doesn't have) and run `db seed` explicitly afterward on every version.
prisma_major="$(node -p "require('prisma/package.json').version.split('.')[0]")"

if [ "$prisma_major" -ge 7 ]; then
  npx prisma migrate reset --force
else
  npx prisma migrate reset --force --skip-seed
fi

npx prisma db seed
