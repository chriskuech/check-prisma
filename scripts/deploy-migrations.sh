#!/usr/bin/env bash
# Applies the PR branch's migrations on top of the base branch's already-
# applied state. Run from the npm project root with DATABASE_URL (and
# DIRECT_DATABASE_URL, where applicable) already exported.
set -euo pipefail

npx prisma migrate deploy
