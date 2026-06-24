#!/usr/bin/env bash
#
# Publish the feature screenshots to a dedicated orphan branch so they can be
# referenced by raw.githubusercontent.com URLs and render inline in the PR
# comment. The branch is rebuilt from scratch and force-pushed every run, so it
# never accumulates history and stays bounded.
#
# We emit the resulting commit SHA; the PR-comment step pins raw URLs to that SHA
# so a given comment keeps rendering even after a later run force-pushes the
# branch (the object survives until git GC).
#
# Best-effort: failures here print a warning and never fail the build.
#
# Env:
#   FEATURE_DIR     directory of PNGs to publish
#   SCREENS_BRANCH  orphan branch name (default: ci-screens)
#   PR_NUMBER       PR number (used to namespace files: pr-<n>/)
#   REPO            owner/repo
#   GH_TOKEN        token with contents:write
#   GITHUB_RUN_ID   (optional) for the commit message
#   GITHUB_OUTPUT   (optional) GitHub Actions output file
#
set -uo pipefail

FEATURE_DIR="${FEATURE_DIR:-artifacts/feature-screens}"
BRANCH="${SCREENS_BRANCH:-ci-screens}"
PR="${PR_NUMBER:-0}"

shopt -s nullglob
pngs=("$FEATURE_DIR"/*.png)
if [ ${#pngs[@]} -eq 0 ]; then
  echo "::warning::no feature screenshots to publish — skipping"
  exit 0
fi

if [ -z "${GH_TOKEN:-}" ] || [ -z "${REPO:-}" ]; then
  echo "::warning::missing GH_TOKEN/REPO — skipping screenshot publish"
  exit 0
fi

work="$(mktemp -d)"
# Fresh repo → single orphan commit, so the pushed branch carries only this run.
git -C "$work" init -q
git -C "$work" symbolic-ref HEAD "refs/heads/$BRANCH"
mkdir -p "$work/pr-$PR"
cp "${pngs[@]}" "$work/pr-$PR/"
git -C "$work" add -A
git -C "$work" \
  -c user.name="terrarium-ci" \
  -c user.email="terrarium-ci@users.noreply.github.com" \
  commit -q -m "CI screenshots for PR #$PR (run ${GITHUB_RUN_ID:-local})"

sha="$(git -C "$work" rev-parse HEAD)"
remote="https://x-access-token:${GH_TOKEN}@github.com/${REPO}.git"

if git -C "$work" push -q --force "$remote" "$BRANCH"; then
  echo "Published ${#pngs[@]} screenshot(s) to '$BRANCH' @ $sha"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "screens_sha=$sha" >> "$GITHUB_OUTPUT"
  fi
else
  echo "::warning::failed to push '$BRANCH' — inline images will fall back to artifact links"
fi

exit 0
