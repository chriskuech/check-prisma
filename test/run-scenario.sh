#!/usr/bin/env bash
# Runs one functional-test scenario end-to-end against a live Postgres
# database, calling the exact scripts/*.sh the composite action runs, in
# the same order, so the test suite exercises the real logic rather than a
# reimplementation of it.
#
# Usage: run-scenario.sh <scenario> <prisma-major> [shared-node-modules-dir]
#
# Scenarios:
#   valid                   -- base and head are both well-formed; everything succeeds
#   pgfence-risk            -- the PR's own new migration is flagged by pgfence
#   historical-risk         -- base already has a migration pgfence would flag, but the
#                              PR's own new migration is clean; the base one is never
#                              re-analyzed, so this succeeds
#   schema-drift            -- applied migrations don't match schema.prisma
#   invalid-migration-sql   -- the PR's latest migration SQL errors when applied
#   bad-seed                -- the base branch's seed script errors
#
# Requires DATABASE_URL (postgresql://postgres:postgres@localhost:5432/test
# by default) to point at a disposable, already-running Postgres instance --
# every scenario resets it via `prisma migrate reset --force`.
set -uo pipefail

scenario="${1:?usage: run-scenario.sh <scenario> <prisma-major> [shared-node-modules-dir]}"
version="${2:?usage: run-scenario.sh <scenario> <prisma-major> [shared-node-modules-dir]}"
shared_node_modules="${3:-}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scripts_dir="$repo_root/scripts"
fixtures_dir="$repo_root/test/fixtures/scenarios"

export DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@localhost:5432/test}"
export DIRECT_DATABASE_URL="${DIRECT_DATABASE_URL:-$DATABASE_URL}"
max_risk="${MAX_RISK:-low}"

case "$scenario" in
  valid)                  base=clean          head=valid-head            expect_fail=none ;;
  pgfence-risk)            base=clean          head=pgfence-risk-head      expect_fail=analyze ;;
  historical-risk)          base=dirty-base      head=historical-risk-head  expect_fail=none ;;
  schema-drift)              base=clean          head=schema-drift-head      expect_fail=drift ;;
  invalid-migration-sql)     base=clean          head=invalid-sql-head       expect_fail=deploy ;;
  bad-seed)                   base=bad-seed-base  head=""                      expect_fail=reset ;;
  *)
    echo "run-scenario: unknown scenario '$scenario'" >&2
    exit 2
    ;;
esac

label="$scenario (prisma $version)"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

fail() {
  echo "FAIL [$label] $1" >&2
  exit 1
}
pass() {
  echo "PASS [$label] $1"
  exit 0
}
run_step() {
  local name="$1"
  shift
  echo "::group::[$label] $name"
  local rc=0
  "$@" || rc=$?
  echo "::endgroup::"
  echo "[$label] $name exited $rc"
  return "$rc"
}

# --- base branch: apply its migrations (and seed) to a fresh database ---
"$repo_root/test/lib/assemble-project.sh" "$fixtures_dir/$base" "$version" "$work_dir/base" "$shared_node_modules"
(cd "$work_dir/base" && run_step "reset-database" bash "$scripts_dir/reset-database.sh")
reset_rc=$?

if [ "$expect_fail" = "reset" ]; then
  [ "$reset_rc" -ne 0 ] && pass "reset-database failed as expected (bad seed script)"
  fail "expected reset-database to fail, but it succeeded"
fi
[ "$reset_rc" -eq 0 ] || fail "reset-database unexpectedly failed"

# --- PR branch: analyze migration risk, then apply on top of base state ---
"$repo_root/test/lib/assemble-project.sh" "$fixtures_dir/$head" "$version" "$work_dir/head" "$shared_node_modules"

(cd "$work_dir/head" && run_step "analyze-risk" bash "$scripts_dir/analyze-risk.sh" "$max_risk" "$work_dir/base/prisma/migrations")
analyze_rc=$?
if [ "$expect_fail" = "analyze" ]; then
  [ "$analyze_rc" -ne 0 ] && pass "analyze-risk failed as expected (unsafe migration)"
  fail "expected analyze-risk to fail, but it succeeded"
fi
[ "$analyze_rc" -eq 0 ] || fail "analyze-risk unexpectedly failed"

(cd "$work_dir/head" && run_step "deploy-migrations" bash "$scripts_dir/deploy-migrations.sh")
deploy_rc=$?
if [ "$expect_fail" = "deploy" ]; then
  [ "$deploy_rc" -ne 0 ] && pass "deploy-migrations failed as expected (invalid migration SQL)"
  fail "expected deploy-migrations to fail, but it succeeded"
fi
[ "$deploy_rc" -eq 0 ] || fail "deploy-migrations unexpectedly failed"

(cd "$work_dir/head" && run_step "check-schema-drift" bash "$scripts_dir/check-schema-drift.sh")
drift_rc=$?
if [ "$expect_fail" = "drift" ]; then
  [ "$drift_rc" -ne 0 ] && pass "check-schema-drift failed as expected (schema/migration mismatch)"
  fail "expected check-schema-drift to fail, but it succeeded"
fi
[ "$drift_rc" -eq 0 ] || fail "check-schema-drift unexpectedly failed"

pass "full pipeline succeeded as expected"
