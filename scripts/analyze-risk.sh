#!/usr/bin/env bash
# Analyzes the PR branch's migration SQL for unsafe DDL using pgfence. Run
# from the npm project root.
#
# Usage: analyze-risk.sh <max-risk>
set -euo pipefail

max_risk="${1:?usage: analyze-risk.sh <max-risk>}"

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

shopt -s globstar
node "$pgfence_dir/node_modules/@flvmnt/pgfence/dist/index.js" \
  analyze --ci --max-risk "$max_risk" prisma/migrations/**/migration.sql
