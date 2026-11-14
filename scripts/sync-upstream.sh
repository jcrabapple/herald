#!/usr/bin/env bash
# Sync the downstream fork with upstream. See FORK.md.
#
#   ./scripts/sync-upstream.sh --check   report only; fetches but changes nothing
#   ./scripts/sync-upstream.sh           fast-forward fork/master, merge upstream into downstream, push
#
# Run from the downstream worktree (~/projects/herald-downstream). Remotes:
#   origin = upstream (Giton22/kyllene), fork = this repo (jcrabapple/herald).
set -euo pipefail

UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-origin}"
FORK_REMOTE="${FORK_REMOTE:-fork}"
INTEGRATION_BRANCH="${INTEGRATION_BRANCH:-downstream}"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not inside a git work tree" >&2; exit 1; }

check_only=0
[ "${1:-}" = "--check" ] && check_only=1

git fetch "$UPSTREAM_REMOTE" --prune --quiet
git fetch "$FORK_REMOTE" --prune --quiet

up="$UPSTREAM_REMOTE/master"
up_sha="$(git rev-parse --short "$up")"
master_behind="$(git rev-list --count "$FORK_REMOTE/master..$up")"
master_ahead="$(git rev-list --count "$up..$FORK_REMOTE/master")"
down_behind="$(git rev-list --count "$FORK_REMOTE/$INTEGRATION_BRANCH..$up")"

echo "upstream master:        $up_sha"
echo "fork/master:            $master_behind behind, $master_ahead ahead"
echo "fork/$INTEGRATION_BRANCH:  $down_behind upstream commits not yet integrated"

if [ "$check_only" = 1 ]; then
  if [ "$master_behind" = 0 ] && [ "$down_behind" = 0 ]; then
    echo "Up to date with upstream."
  else
    echo "Sync needed: run ./scripts/sync-upstream.sh"
  fi
  exit 0
fi

if [ "$master_ahead" != 0 ]; then
  echo "fork/master has $master_ahead commits not in upstream; refusing to reset. Investigate first." >&2
  exit 1
fi

# 1. Fast-forward the mirror (no force: it must be a strict fast-forward).
if [ "$master_behind" != 0 ]; then
  git push "$FORK_REMOTE" "$up:refs/heads/master"
  echo "fork/master fast-forwarded to $up_sha"
else
  echo "fork/master already current"
fi

# 2. Merge upstream into the integration branch.
git checkout "$INTEGRATION_BRANCH"
if git merge --no-ff "$up" -m "Downstream: sync upstream master ($up_sha)"; then
  git push "$FORK_REMOTE" "$INTEGRATION_BRANCH"
  echo "Synced fork/$INTEGRATION_BRANCH. Verify CI on the pushed head before tagging a release."
else
  echo "" >&2
  echo "Merge conflicts. Resolve them, commit, then: git push $FORK_REMOTE $INTEGRATION_BRANCH" >&2
  echo "Conflicted files:" >&2
  git diff --name-only --diff-filter=U >&2
  exit 1
fi