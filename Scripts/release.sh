#!/bin/zsh
# Tags the current ButchKit HEAD as a release and publishes it on GitHub.
#
# Usage: Scripts/release.sh 2.0.0
#
# Runs by itself from Scripts/git-hooks/post-merge when a version branch is
# merged into main, see README.md, "Releasing". Calling it by hand is the
# fallback.
#
# The release covers ButchKit only. The apps pick up the new version through
# their own pipelines; this script never touches them.
#
# The GitHub release is a readable changelog per version; SwiftPM only needs
# the tag. Its notes are the commit subjects since the previous tag, because
# GitHub's own generated notes only list pull requests and main is committed
# to directly.
set -euo pipefail

# Xcode runs hooks without the login shell's PATH, where gh lives.
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

version=${1:?usage: release.sh <version, e.g. 2.0.0>}
kit=$(cd "$(dirname "$0")/.." && pwd)

[[ $version =~ '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' ]] || { echo "'$version' is not a version like 2.0.24"; exit 1 }

cd "$kit"
[[ $(git branch --show-current) == main ]] || { echo "ButchKit is not on main"; exit 1 }
[[ -z $(git status --porcelain) ]] || { echo "ButchKit has uncommitted changes"; exit 1 }
git rev-parse -q --verify "refs/tags/v$version" >/dev/null && { echo "v$version is already tagged"; exit 1 }
git ls-remote --exit-code --tags origin "refs/tags/v$version" >/dev/null && { echo "v$version is already tagged on GitHub"; exit 1 }
gh auth status >/dev/null 2>&1 || { echo "gh is not logged in, run: gh auth login"; exit 1 }

previous=$(git describe --tags --abbrev=0)
git tag "v$version"
git push origin main "v$version"
gh release create "v$version" --title "v$version" --notes "$(git log --pretty='- %s' "$previous..HEAD")"
