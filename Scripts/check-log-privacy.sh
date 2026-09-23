#!/bin/bash
# Fails when ButchKit's own sources can log an error's prose. ButchKit logs an
# error as `error.logCode` and nothing else: `localizedDescription` quotes file
# names and paths, and `String(describing:)`, `debugDescription` or the error
# interpolated whole write associated values, which can hold user data. All of
# it would end up in the diagnostics file every app built on ButchKit lets its
# users share, and a `.private` annotation only redacts it there.
#
# Stricter than Documentation/LoggingStrategy.md on purpose. That page lets an
# app add the description for a domain that never quotes user data; ButchKit's
# own code takes no such exception, so one text check can hold it.
#
# Bash rather than zsh like the other scripts: CI runs this on Linux, where
# bash is already there.
#
# Usage: Scripts/check-log-privacy.sh
#
# A text check, not a parser. It flags every `localizedDescription`,
# `String(describing:` and `debugDescription` outside comments, because such a
# value can be built on the line before the log call, and an error interpolated
# whole on a line that carries `privacy:`. Should a legitimate use outside
# logging ever appear, narrow the check here rather than rephrasing the code to
# slip past it.
set -euo pipefail

cd "$(dirname "$0")/.."

code_lines() {
  grep -rnE --include='*.swift' "$1" Sources | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' || true
}

findings=$(
  code_lines 'localizedDescription|String\(describing:|debugDescription'
  code_lines 'privacy:' | grep -E '\\\(error[,)]' || true
)

if [[ -n $findings ]]; then
  echo "Error prose in reach of a log statement. Log errors as \\(error.logCode, privacy: .public) only:"
  echo "$findings"
  exit 1
fi
