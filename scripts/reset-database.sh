#!/usr/bin/env bash
# Applies the base branch's migrations (and seed, if configured) to a fresh
# database. Run from the npm project root with DATABASE_URL (and, for
# schemas that declare one, DIRECT_DATABASE_URL) already exported.
set -euo pipefail

npx prisma migrate reset --force
