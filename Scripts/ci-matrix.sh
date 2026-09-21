#!/bin/zsh
# Prints the CI test matrix as JSON: iOS and macOS, each on the minimum that
# Package.swift declares, on 26, and on the newest release GitHub offers.
#
# Usage: LATEST_RUNNER=xcode-27 Scripts/ci-matrix.sh
#
# Raising a minimum in Package.swift moves the matrix with it. 26 is the one
# fixed version, and it is left out once a minimum reaches it.
#
# macOS is tested on the runner's own system, so its minimum needs a runner of
# that version. ButchKit needs Xcode 26, which runs on macOS 15 at the lowest,
# so a lower minimum is compiled against but tested on 15.
set -euo pipefail

latest=${LATEST_RUNNER:?set LATEST_RUNNER to the runner with the newest Xcode}
cd "$(dirname "$0")/.."

platforms=$(swift package dump-package | jq '.platforms')
ios_min=$(jq -r '.[] | select(.platformName == "ios") | .version' <<<"$platforms")
mac_min=$(jq -r '.[] | select(.platformName == "macos") | .version' <<<"$platforms")
mac_oldest=$(( ${mac_min%%.*} < 15 ? 15 : ${mac_min%%.*} ))

entry() { jq -nc --arg platform $1 --arg name $2 --arg runner $3 --arg version $4 '$ARGS.named' }

{
  entry ios "iOS $ios_min" macos-26 "$ios_min"
  # Apple no longer offers the 26.0 runtime for download; macos-15 has it installed.
  (( ${ios_min%%.*} < 26 )) && entry ios "iOS 26.0" macos-15 26.0
  entry ios "iOS latest" "$latest" latest

  if (( mac_oldest > ${mac_min%%.*} )); then
    entry macos "macOS $mac_oldest (min $mac_min)" "macos-$mac_oldest" "$mac_oldest"
  else
    entry macos "macOS $mac_oldest" "macos-$mac_oldest" "$mac_oldest"
  fi
  (( mac_oldest < 26 )) && entry macos "macOS 26" macos-26 26
  entry macos "macOS latest" "$latest" latest
} | jq -sc .
