#!/usr/bin/env bash
# Validates the three data/ files that correspond to upstream's three
# data/meson.build test() entries (Validate desktop file, Validate appstream
# file, Validate schema file). Run inside the dev shell, where
# desktop-file-validate, appstreamcli and glib-compile-schemas are on PATH:
#
#   nix develop --command script/validate-data.sh
#
# Exits non-zero on the first failing check, printing which of the three it
# was, so this is wired as this port's own equivalent of the meson tests
# upstream runs in CI.
set -euo pipefail

cd "$(dirname "$0")/.."

status=0

echo "== Validate desktop file =="
if ! desktop-file-validate data/dev.bragefuglseth.Fretboard.desktop; then
  status=1
fi

echo "== Validate appstream file =="
if ! appstreamcli validate --no-net data/dev.bragefuglseth.Fretboard.metainfo.xml; then
  status=1
fi

echo "== Validate schema file =="
if ! glib-compile-schemas --strict --dry-run data/; then
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "All three data files are valid."
else
  echo "One or more data files failed validation." >&2
fi

exit "$status"
