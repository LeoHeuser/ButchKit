#!/bin/zsh
# Tags the current ButchKit HEAD as a release and pins the consuming apps to it.
#
# Usage: Scripts/release.sh 1.4.5
#
# Local development runs against the sibling checkout via each app's gitignored
# .xcworkspace, so Xcode never touches the app's committed Package.resolved.
# Xcode Cloud builds from exactly that file, which is why this script writes the
# new pin there and commits it. That is the only step that used to require
# opening the .xcodeproj itself.
#
# The GitHub release is a readable changelog per version; SwiftPM only needs
# the tag. Its notes are the commit subjects since the previous tag, because
# GitHub's own generated notes only list pull requests and main is committed
# to directly.
set -euo pipefail

version=${1:?usage: release.sh <version, e.g. 1.4.5>}
kit=$(cd "$(dirname "$0")/.." && pwd)
apps=("$kit/../Kadidi" "$kit/../VideoKlipp" "$kit/../Docscn" "$kit/../FocusSix" "$kit/../VideoSkript")

cd "$kit"
[[ $(git branch --show-current) == main ]] || { echo "ButchKit is not on main"; exit 1 }
[[ -z $(git status --porcelain) ]] || { echo "ButchKit has uncommitted changes"; exit 1 }
gh auth status >/dev/null 2>&1 || { echo "gh is not logged in, run: gh auth login"; exit 1 }

previous=$(git describe --tags --abbrev=0)
git tag "v$version"
git push origin main "v$version"
gh release create "v$version" --title "v$version" --notes "$(git log --pretty='- %s' "$previous..HEAD")"
revision=$(git rev-parse HEAD)

for app in $apps; do
  cd "$app"
  name=$(basename "$app")
  resolved="$name.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

  # Rewrite in Xcode's own JSON style (sorted keys, 2-space indent, "key" : value)
  # so the next time Xcode saves the file the diff stays at the two pin lines.
  python3 - "$resolved" "$revision" "$version" <<'PY'
import json, sys
path, revision, version = sys.argv[1:]
with open(path) as f:
    data = json.load(f)
pin = next(p for p in data["pins"] if p["identity"] == "butchkit")
pin["state"] = {"revision": revision, "version": version}
with open(path, "w") as f:
    json.dump(data, f, indent=2, sort_keys=True, separators=(",", " : "))
    f.write("\n")
PY

  git add "$resolved"
  git commit -m "Bump ButchKit to $version"
  # Apps may sit on a release branch; the bump lands wherever the app is.
  if git remote get-url origin >/dev/null 2>&1; then
    git push origin HEAD
  else
    echo "$name has no origin remote, bump committed but not pushed"
  fi
done
