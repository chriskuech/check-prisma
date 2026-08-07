#!/usr/bin/env bash
# Assembles a scenario fixture into a real commit and force-pushes it to a
# throwaway branch in this repository, so the composite action can be
# exercised end-to-end through real actions/checkout refs -- exactly how a
# real pull request presents base/head state to it -- rather than only
# through scripts/*.sh directly.
#
# Uses a `git worktree` off the caller's own checkout so it can push
# through whatever credentials that checkout already has configured
# (actions/checkout's persisted token), without disturbing the caller's
# working tree.
#
# Usage: push-fixture-branch.sh <fixture-dir> <prisma-major> <branch-name>
#
# Prints the pushed commit SHA on success.
set -euo pipefail

fixture_dir="$1"
version="$2"
branch="$3"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
staging_dir="$(mktemp -d)"
worktree_dir="$(mktemp -d)"

cleanup() {
  git -C "$repo_root" worktree remove --force "$worktree_dir" >/dev/null 2>&1 || rm -rf "$worktree_dir"
  rm -rf "$staging_dir"
}
trap cleanup EXIT

# Assemble in a scratch dir first -- assemble-project.sh wipes its target
# directory, which would destroy the worktree's .git pointer if assembled
# directly into it.
"$repo_root/test/lib/assemble-project.sh" "$fixture_dir" "$version" "$staging_dir"

git -C "$repo_root" worktree add --detach --quiet "$worktree_dir" >/dev/null
git -C "$worktree_dir" checkout --quiet --orphan "$branch"
git -C "$worktree_dir" rm -rf --quiet . >/dev/null 2>&1 || true
find "$worktree_dir" -mindepth 1 -maxdepth 1 -not -name '.git' -exec rm -rf {} +

cp "$staging_dir/package.json" "$worktree_dir/package.json"
cp "$staging_dir/package-lock.json" "$worktree_dir/package-lock.json"
if [ -f "$staging_dir/prisma.config.ts" ]; then
  cp "$staging_dir/prisma.config.ts" "$worktree_dir/prisma.config.ts"
fi
cp -r "$staging_dir/prisma" "$worktree_dir/prisma"

git -C "$worktree_dir" add -A
git \
  -C "$worktree_dir" \
  -c user.name="check-prisma-test-fixtures" \
  -c user.email="actions@users.noreply.github.com" \
  commit --quiet -m "test fixture: $branch"

git -C "$worktree_dir" push --force --quiet origin "HEAD:refs/heads/$branch"
git -C "$worktree_dir" rev-parse HEAD
