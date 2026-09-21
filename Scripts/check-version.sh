#!/bin/zsh
# Fails unless the argument can become a new ButchKit release: a version like
# 2.0.24 (one to three digits per part) that is not tagged yet.
#
# Usage: Scripts/check-version.sh 2.1.0
#
# The one place these rules live. The post-merge hook, the Release workflow
# and release.sh all ask it.
set -euo pipefail

version=${1:?usage: check-version.sh <version, e.g. 2.0.24>}
cd "$(dirname "$0")/.."

[[ $version =~ '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' ]] || { echo "'$version' is not a version like 2.0.24"; exit 1 }
git rev-parse -q --verify "refs/tags/v$version" >/dev/null && { echo "v$version is already tagged"; exit 1 }
git ls-remote --exit-code --tags origin "refs/tags/v$version" >/dev/null && { echo "v$version is already tagged on GitHub"; exit 1 }
exit 0
