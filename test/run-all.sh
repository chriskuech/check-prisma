#!/usr/bin/env bash
# Runs every scenario against a single Prisma major version, sharing one
# `npm install` across all of them (the fixture package.json is identical
# per version regardless of scenario).
#
# Usage: run-all.sh <prisma-major>
#
# Requires a disposable Postgres reachable at DATABASE_URL (defaults to
# postgresql://postgres:postgres@localhost:5432/test).
set -uo pipefail

version="${1:?usage: run-all.sh <prisma-major>}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

scenarios=(valid pgfence-risk historical-risk schema-drift invalid-migration-sql bad-seed)

install_dir="$(mktemp -d)"
trap 'rm -rf "$install_dir"' EXIT
cp "$repo_root/test/fixtures/versions/$version/package.json" "$install_dir/package.json"
echo "installing prisma@$version fixture dependencies once for all scenarios..."
(cd "$install_dir" && npm install --no-audit --no-fund --loglevel=error)

status=0
for scenario in "${scenarios[@]}"; do
  if ! "$repo_root/test/run-scenario.sh" "$scenario" "$version" "$install_dir/node_modules"; then
    status=1
  fi
done

exit "$status"
