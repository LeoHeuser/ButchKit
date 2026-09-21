#!/bin/zsh
# Tags the current ButchKit HEAD as a release and publishes it on GitHub.
#
# Usage: Scripts/release.sh 2.1.0
#
# The Release workflow runs this when a version pull request is merged and
# build and tests passed on macOS and iOS; see README.md, "Releasing". Calling
# it by hand skips that gate and is only the fallback.
#
# The release covers ButchKit only. Apps that depend on it pick up the new
# version through their own dependency updates; this script never touches them.
#
# The GitHub release is a readable changelog per version; SwiftPM only needs
# the tag. Its notes are the commit subjects since the previous tag, because
# GitHub's own generated notes only list pull requests and main is committed
# to directly.
set -euo pipefail

version=${1:?usage: release.sh <version, e.g. 2.1.0>}
kit=$(cd "$(dirname "$0")/.." && pwd)

cd "$kit"
Scripts/check-version.sh "$version"
# The workflow checks out the tested commit, not the branch, so HEAD only has to be on main.
git fetch -q origin main
git merge-base --is-ancestor HEAD origin/main || { echo "HEAD is not on main"; exit 1 }
[[ -z $(git status --porcelain) ]] || { echo "ButchKit has uncommitted changes"; exit 1 }
gh auth status >/dev/null 2>&1 || { echo "gh is not logged in, run: gh auth login"; exit 1 }

previous=$(git describe --tags --abbrev=0)
git tag "v$version"
git push origin "v$version"
gh release create "v$version" --title "v$version" --notes "$(git log --pretty='- %s' "$previous..HEAD")"
