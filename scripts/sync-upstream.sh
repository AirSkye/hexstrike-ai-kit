#!/usr/bin/env bash

set -euo pipefail

# sync-upstream.sh
# - Adds/updates upstream remote to fixed URL
# - Fetches and merges the upstream default branch into a local sync branch
# - Preserves local Dockerfile-related files (Dockerfile, .dockerignore, docker/**)
# - Generates a merge report and pauses on conflicts for manual resolution

print_usage() {
  cat <<'USAGE'
Usage: scripts/sync-upstream.sh [--remote upstream] [--target-branch upstream-sync]

Options:
  --remote <name>         Upstream remote name (default: upstream)
  --target-branch <name>  Local branch to receive merges (default: upstream-sync)
  -h, --help              Show this help

Behavior:
  - Ensures clean working tree
  - Adds/updates upstream remote to fixed URL
  - Detects upstream default branch (HEAD), falling back to main/master
  - Merges upstream into target branch
  - Preserves local Dockerfile-related files during merge
  - Writes MERGE_UPSTREAM_REPORT.md and pauses on conflicts
USAGE
}

UPSTREAM_URL="https://github.com/0x4m4/hexstrike-ai"
UPSTREAM_REMOTE="upstream"
TARGET_BRANCH="upstream-sync"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote)
      [[ $# -ge 2 ]] || { echo "Missing value for --remote" >&2; exit 1; }
      UPSTREAM_REMOTE="$2"; shift 2;;
    --target-branch)
      [[ $# -ge 2 ]] || { echo "Missing value for --target-branch" >&2; exit 1; }
      TARGET_BRANCH="$2"; shift 2;;
    -h|--help)
      print_usage; exit 0;;
    *)
      echo "Unknown argument: $1" >&2; print_usage; exit 1;;
  esac
done

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [[ -z "$REPO_ROOT" ]]; then
  echo "Not inside a git repository." >&2
  exit 1
fi
cd "$REPO_ROOT"

echo "[sync-upstream] Repository root: $REPO_ROOT"

# Ensure clean working tree (no unstaged or staged changes)
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree is not clean. Commit or stash your changes first." >&2
  exit 1
fi

# Ensure upstream remote exists and points to fixed URL
if ! git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
  echo "Adding upstream remote: $UPSTREAM_URL"
  git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
else
  CURRENT_URL=$(git remote get-url "$UPSTREAM_REMOTE")
  if [[ "$CURRENT_URL" != "$UPSTREAM_URL" ]]; then
    echo "Updating upstream remote URL: $CURRENT_URL -> $UPSTREAM_URL"
    git remote set-url "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
  fi
fi

echo "Fetching from $UPSTREAM_REMOTE..."
git fetch "$UPSTREAM_REMOTE" --prune

# Determine upstream default branch
UPSTREAM_HEAD=$(git remote show "$UPSTREAM_REMOTE" 2>/dev/null | awk '/HEAD branch/ {print $NF}')
UPSTREAM_BRANCH=${UPSTREAM_HEAD:-main}
if ! git ls-remote --exit-code --heads "$UPSTREAM_REMOTE" "$UPSTREAM_BRANCH" >/dev/null 2>&1; then
  if git ls-remote --exit-code --heads "$UPSTREAM_REMOTE" master >/dev/null 2>&1; then
    UPSTREAM_BRANCH="master"
  else
    echo "Could not find 'main' or 'master' on remote '$UPSTREAM_REMOTE'." >&2
    exit 1
  fi
fi
echo "Detected upstream branch: $UPSTREAM_REMOTE/$UPSTREAM_BRANCH"

# Switch/create target branch (based on current HEAD)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Preparing target branch: $TARGET_BRANCH (current: $CURRENT_BRANCH)"
if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
  git switch "$TARGET_BRANCH" >/dev/null 2>&1 || git checkout "$TARGET_BRANCH"
else
  git switch -c "$TARGET_BRANCH" >/dev/null 2>&1 || git checkout -b "$TARGET_BRANCH"
fi

# Prepare list of upstream commits (for report) before merging
UPSTREAM_COMMITS=$(git log --oneline --no-decorate --no-merges "HEAD..$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" || true)

# Preserve Dockerfile-related files before merge
IGNORE_PATTERNS=(
  "Dockerfile"
  "Dockerfile.*"
  ".dockerignore"
  "docker/**"
  "README.md"
  "hexstrike-ai-kit.png"
)

TMP_DIR=$(mktemp -d -t sync-upstream-XXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

# Enable useful globbing options when available (no-op if unsupported)
shopt -s globstar nullglob 2>/dev/null || true

pushd "$REPO_ROOT" >/dev/null

PRE_LIST="$TMP_DIR/pre_existing.txt"
AFTER_LIST="$TMP_DIR/after_existing.txt"
mkdir -p "$TMP_DIR/snapshot"
: > "$PRE_LIST"

for pattern in "${IGNORE_PATTERNS[@]}"; do
  for path in $pattern; do
    if [[ -e "$path" ]]; then
      mkdir -p "$TMP_DIR/snapshot/$(dirname "$path")"
      cp -a "$path" "$TMP_DIR/snapshot/$path"
      printf "%s\n" "$path" >> "$PRE_LIST"
    fi
  done
done
sort -u "$PRE_LIST" -o "$PRE_LIST"

BEFORE_HEAD=$(git rev-parse HEAD)
echo "Merging $UPSTREAM_REMOTE/$UPSTREAM_BRANCH into $TARGET_BRANCH..."
set +e
git merge --no-ff --no-edit "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
MERGE_STATUS=$?
set -e

# Restore Dockerfile-related files after merge
: > "$AFTER_LIST"
for pattern in "${IGNORE_PATTERNS[@]}"; do
  for path in $pattern; do
    if [[ -e "$path" ]]; then
      printf "%s\n" "$path" >> "$AFTER_LIST"
    fi
  done
done
sort -u "$AFTER_LIST" -o "$AFTER_LIST"

# Remove files created by merge (present after, not present before)
if [[ -s "$AFTER_LIST" ]]; then
  comm -13 "$PRE_LIST" "$AFTER_LIST" | while IFS= read -r created; do
    [[ -n "$created" ]] || continue
    git rm -rf --ignore-unmatch -- "$created" 2>/dev/null || rm -rf -- "$created" || true
  done
fi

# Restore previously existing files and stage them to override merge result
if [[ -s "$PRE_LIST" ]]; then
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    mkdir -p "$(dirname "$path")"
    cp -a "$TMP_DIR/snapshot/$path" "$path"
    git add -f -- "$path" || true
  done < "$PRE_LIST"
fi

popd >/dev/null

REPORT="MERGE_UPSTREAM_REPORT.md"

if [[ $MERGE_STATUS -ne 0 ]]; then
  # Merge has conflicts; generate report and pause for manual resolution
  CONFLICTS=$(git ls-files -u | cut -f2 | sort -u)
  {
    echo "# Upstream merge report"
    echo
    echo "- Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo "- Target branch: $TARGET_BRANCH"
    echo "- Upstream: $UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
    echo
    echo "## Upstream commits"
    if [[ -n "$UPSTREAM_COMMITS" ]]; then
      echo "$UPSTREAM_COMMITS" | sed 's/^/- /'
    else
      echo "- (no new commits detected)"
    fi
    echo
    echo "## Conflicts"
    if [[ -n "$CONFLICTS" ]]; then
      echo "$CONFLICTS" | sed 's/^/- /'
    else
      echo "- (unknown)"
    fi
    echo
    echo "Dockerfile-related files were preserved from the local working tree."
    echo
    echo "After resolving conflicts, run:"
    echo
    echo "  git add -A"
    echo "  git commit"
  } > "$REPORT"

  echo "Merge has conflicts. Wrote $REPORT. Resolve conflicts and commit."
  exit 1
fi

AFTER_HEAD=$(git rev-parse HEAD)

if [[ "$AFTER_HEAD" == "$BEFORE_HEAD" ]]; then
  echo "Already up to date. No merge performed."
  exit 0
fi

# Write report and amend merge commit message to reference it
{
  echo "# Upstream merge report"
  echo
  echo "- Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
  echo "- Target branch: $TARGET_BRANCH"
  echo "- Upstream: $UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
  echo
  echo "## Upstream commits"
  if [[ -n "$UPSTREAM_COMMITS" ]]; then
    echo "$UPSTREAM_COMMITS" | sed 's/^/- /'
  else
    echo "- (no new commits detected)"
  fi
  echo
  echo "Dockerfile-related files were preserved from the local working tree."
} > "$REPORT"

git add "$REPORT" || true

# If the previous command created a merge commit, amend its message to include context
if git rev-parse -q --verify HEAD^2 >/dev/null 2>&1; then
  git commit --amend -m "Merge $UPSTREAM_REMOTE/$UPSTREAM_BRANCH into $TARGET_BRANCH (preserve Dockerfile-related files)" -m "See $REPORT for details."
else
  # Fallback: create a separate commit for the report
  git commit -m "chore: add upstream merge report (Dockerfile files preserved)"
fi

echo "Merge completed successfully and report written to $REPORT."


