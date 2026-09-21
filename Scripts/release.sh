#!/bin/zsh
# Tags the current ButchKit HEAD as a release and publishes it on GitHub.
#
# Usage: Scripts/release.sh 2.0.0
#
# The release covers ButchKit only. The apps pick up the new version through
# their own pipelines; this script never touches them.
#
# The GitHub release is a readable changelog per version; SwiftPM only needs
# the tag. Its notes are the commit subjects since the previous tag, because
# GitHub's own generated notes only list pull requests and main is committed
# to directly.
set -euo pipefail

version=${1:?usage: release.sh <version, e.g. 2.0.0>}
kit=$(cd "$(dirname "$0")/.." && pwd)

cd "$kit"
[[ $(git branch --show-current) == main ]] || { echo "ButchKit is not on main"; exit 1 }
[[ -z $(git status --porcelain) ]] || { echo "ButchKit has uncommitted changes"; exit 1 }
gh auth status >/dev/null 2>&1 || { echo "gh is not logged in, run: gh auth login"; exit 1 }

previous=$(git describe --tags --abbrev=0)
git tag "v$version"
git push origin main "v$version"
gh release create "v$version" --title "v$version" --notes "$(git log --pretty='- %s' "$previous..HEAD")"
