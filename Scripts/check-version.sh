#!/bin/zsh
# Fails unless the argument can become a new ButchKit release: a version like
# 2.0.24 (one to three digits per part), not tagged yet, and higher than every
# version tagged so far. After v2.0.0, 1.9.3 is refused, and so is a hotfix
# for an older major.
#
# Usage: Scripts/check-version.sh 2.1.0
#
# The one place these rules live. The Release workflow and release.sh both
# ask it.
set -euo pipefail

version=${1:?usage: check-version.sh <version, e.g. 2.0.24>}
cd "$(dirname "$0")/.."

[[ $version =~ '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' ]] || { echo "'$version' is not a version like 2.0.24"; exit 1 }
git rev-parse -q --verify "refs/tags/v$version" >/dev/null && { echo "v$version is already tagged"; exit 1 }
git ls-remote --exit-code --tags origin "refs/tags/v$version" >/dev/null && { echo "v$version is already tagged on GitHub"; exit 1 }

# Highest vX.Y.Z tag here or on GitHub, compared part by part as numbers so
# that 2.0.24 is above 2.0.9.
bynumber=(sort -t. -k1,1n -k2,2n -k3,3n)
latest=$( { git tag -l 'v*'; git ls-remote --tags --refs origin 'v*' | sed 's|.*refs/tags/||' } \
  | sed -n 's/^v\([0-9]*\.[0-9]*\.[0-9]*\)$/\1/p' | $bynumber | tail -1)
if [[ -n $latest && $(print -l "$latest" "$version" | $bynumber | tail -1) != $version ]]; then
  echo "'$version' is not higher than the latest release v$latest"; exit 1
fi
exit 0
