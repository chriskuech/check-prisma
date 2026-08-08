#!/usr/bin/env bash
# Analyzes the PR branch's *new* migration SQL for unsafe DDL using pgfence --
# migrations already present on the base branch are never re-analyzed, no
# matter how they'd score today (see the "scoped to new migrations" note
# below). Run from the npm project root.
#
# Usage: analyze-risk.sh <max-risk> <base-migrations-dir>
#
# <base-migrations-dir> is the base branch's prisma/migrations directory
# (or any empty directory, if the base branch has none) -- every migration
# folder name found here is treated as pre-existing and excluded from
# analysis; every folder under ./prisma/migrations *not* found here is new
# and gets analyzed.
set -euo pipefail

max_risk="${1:?usage: analyze-risk.sh <max-risk> <base-migrations-dir>}"
base_migrations_dir="${2:?usage: analyze-risk.sh <max-risk> <base-migrations-dir>}"

# Scoped to new migrations, deliberately: a migration already on the base
# branch has already been applied wherever this project deploys, and rerunning
# risk analysis on it doesn't change that -- it only means a PR that touches
# no migrations of its own can never pass once *any* historical migration
# scores above max-risk, forever, with no action available to the PR's author
# (rewriting an already-applied migration's SQL changes its checksum, which
# breaks `prisma migrate deploy` on every environment that already applied
# it -- a much worse outcome than the risk this check exists to catch).
# Historical risk doesn't stop being real, but re-litigating it on every
# unrelated future PR isn't how to act on it.
new_migrations=()
shopt -s nullglob
for dir in prisma/migrations/*/; do
  name="$(basename "$dir")"
  if [ ! -d "$base_migrations_dir/$name" ]; then
    new_migrations+=("prisma/migrations/$name/migration.sql")
  fi
done

if [ "${#new_migrations[@]}" -eq 0 ]; then
  echo "No migrations added since the base branch -- nothing to analyze."
  exit 0
fi

echo "Analyzing ${#new_migrations[@]} new migration(s):"
printf '  %s\n' "${new_migrations[@]}"

# `npx @flvmnt/pgfence ...` resolves and executes the package's
# node_modules/.bin/pgfence symlink. pgfence 0.6.x's entry point gates its
# whole CLI behind:
#   const isMainModule = process.argv[1] != null && path.resolve(process.argv[1]) === __filename;
#   if (isMainModule) { program.parse(); }
# `process.argv[1]` is the symlink path (path.resolve doesn't touch the
# filesystem), but `__filename`/`import.meta.url` is the symlink's real
# target -- they never match through a `.bin` symlink, so `isMainModule` is
# always false and `npx @flvmnt/pgfence ...` silently does nothing and
# exits 0, regardless of what the migrations contain. Work around it by
# installing pgfence into an isolated directory (so it can't collide with
# or mutate the project's own node_modules/package-lock.json) and invoking
# its entry file directly, bypassing the `.bin` symlink entirely.
pgfence_dir="$(mktemp -d)"
trap 'rm -rf "$pgfence_dir"' EXIT
(cd "$pgfence_dir" && npm install --no-audit --no-fund --loglevel=error @flvmnt/pgfence)

node "$pgfence_dir/node_modules/@flvmnt/pgfence/dist/index.js" \
  analyze --ci --max-risk "$max_risk" "${new_migrations[@]}"
