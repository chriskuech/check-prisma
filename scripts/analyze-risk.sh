#!/usr/bin/env bash
# Analyzes the PR branch's migration SQL for unsafe DDL using pgfence. Run
# from the npm project root.
#
# Usage: analyze-risk.sh <max-risk>
set -euo pipefail

max_risk="${1:?usage: analyze-risk.sh <max-risk>}"

shopt -s globstar
npx @flvmnt/pgfence analyze --ci --max-risk "$max_risk" prisma/migrations/**/migration.sql
