#!/usr/bin/env bash
# Run a buildspec's phases locally, in order, in one shell.
# Usage: usms-buildspec-run.sh <app-dir> [buildspec-file]
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${1:-}"
SPEC="${2:-buildspec.yml}"
if [ -z "$APP_DIR" ] || [ ! -d "$APP_DIR" ]; then
  echo "usage: $0 <app-dir> [buildspec-file]" >&2
  exit 2
fi
APP_ABS="$(cd "$APP_DIR" && pwd)"
if [ ! -f "$APP_ABS/$SPEC" ]; then
  echo "no $SPEC in $APP_ABS" >&2
  exit 2
fi

GEN="${TMPDIR:-/tmp}/usms-buildspec-$$.sh"

python3 "$HERE/usms-buildspec-gen.py" "$APP_ABS/$SPEC" "$GEN"
RC=$?
[ "$RC" -ne 0 ] && { echo "could not parse the buildspec" >&2; exit "$RC"; }

echo "--- generated script: $GEN ---"
bash -n "$GEN" && echo "generated script is valid bash"
echo "--- running in $APP_ABS ---"
( cd "$APP_ABS" && bash "$GEN" )
STATUS=$?
echo "--- local build exit status: $STATUS ---"
rm -f "$GEN"
exit "$STATUS"
