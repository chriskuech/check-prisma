#!/usr/bin/env bash
# Assembles a runnable npm+Prisma project from a scenario fixture plus a
# Prisma major version, so the extracted scripts/*.sh can be exercised
# exactly as the composite action runs them.
#
# Usage: assemble-project.sh <fixture-dir> <prisma-major> <target-dir> [shared-node-modules-dir]
#
# If a shared node_modules dir is given, it's symlinked in instead of
# running `npm install` again (the fixture's package.json is identical for
# every scenario at a given Prisma version, so the install only needs to
# happen once per version -- see test/run-all.sh).
set -euo pipefail

fixture_dir="$1"
version="$2"
target_dir="$3"
shared_node_modules="${4:-}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
version_dir="$repo_root/test/fixtures/versions/$version"

if [ ! -d "$fixture_dir" ]; then
  echo "assemble-project: no such fixture dir: $fixture_dir" >&2
  exit 2
fi
if [ ! -d "$version_dir" ]; then
  echo "assemble-project: no such Prisma version fixture: $version_dir" >&2
  exit 2
fi

rm -rf "$target_dir"
mkdir -p "$target_dir/prisma"

cp "$version_dir/package.json" "$target_dir/package.json"
if [ -f "$version_dir/prisma.config.ts" ]; then
  cp "$version_dir/prisma.config.ts" "$target_dir/prisma.config.ts"
fi

cat "$version_dir/schema-header.prisma" "$fixture_dir/schema.prisma.body" > "$target_dir/prisma/schema.prisma"
cp "$fixture_dir/seed.js" "$target_dir/prisma/seed.js"
cp -r "$fixture_dir/migrations" "$target_dir/prisma/migrations"

if [ -n "$shared_node_modules" ]; then
  ln -s "$shared_node_modules" "$target_dir/node_modules"
else
  (cd "$target_dir" && npm install --no-audit --no-fund --loglevel=error)
fi
