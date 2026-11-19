#!/usr/bin/env bash
# Rebase the Sprites provider patch series onto current upstream Roomote.
#
# Usage:
#   ./sync.sh            # rebase onto origin/develop
#   ./sync.sh <ref>      # rebase onto an explicit upstream ref
#
# On conflict the script stops with the series paused, so you can resolve in
# normal git terms and then run `git am --continue`.

set -euo pipefail

REPO="${ROOMOTE_REPO:-$HOME/src/Roomote}"
UPSTREAM="${1:-develop}"
BRANCH="feat/sprites-provider"
PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/patches"

if [[ ! -d "$REPO/.git" ]]; then
  echo "error: Roomote checkout not found at $REPO" >&2
  echo "       set ROOMOTE_REPO=/path/to/Roomote and retry" >&2
  exit 1
fi

cd "$REPO"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree is dirty; commit or stash first" >&2
  exit 1
fi

echo "==> fetching upstream"
git fetch --prune origin

echo "==> dropping any previous $BRANCH"
git branch -D "$BRANCH" >/dev/null 2>&1 || true

echo "==> branching from origin/$UPSTREAM"
git checkout -q -b "$BRANCH" "origin/$UPSTREAM"

echo "==> applying $(ls -1 "$PATCH_DIR"/*.patch | wc -l | tr -d ' ') patches"
if ! git am --3way "$PATCH_DIR"/*.patch; then
  cat >&2 <<'EOF'

CONFLICT: the series is paused mid-apply.

  1. Resolve the conflicting files.
  2. git add <files>
  3. git am --continue

If a patch is obsolete because upstream landed equivalent code, drop it with
`git am --skip` and then refresh the series so the patch dir stays honest:

  git format-patch "origin/<upstream>"..HEAD -o patches --no-signature

EOF
  exit 1
fi

echo "==> done: $(git rev-parse --short HEAD) on $BRANCH"
git diff --stat "origin/$UPSTREAM"..HEAD
