#!/usr/bin/env bash
# Merges po/*.po translations into the two gettext-templated data files and
# writes the results data/meson.build would have produced via i18n.merge_file
# upstream: data/*.desktop and data/*.metainfo.xml.
#
# Without this step the two files are shipped as static English text (plus
# whatever was baked in at the last manual edit), so none of the 36 languages
# in po/LINGUAS apply to their strings: the "Look up guitar chords" comment,
# the "guitar;chords" search keywords, the screenshot captions and the GNOME
# Circle blurb. msgfmt --desktop / --xml, run against po/ the same way
# meson's i18n.merge_file calls them, is what actually applies the catalogue.
#
# Run inside the dev shell, where `msgfmt` (pkgs.gettext) is on PATH:
#
#   nix develop --command script/build-data.sh
#
# Regenerates:
#   data/dev.bragefuglseth.Fretboard.desktop
#   data/dev.bragefuglseth.Fretboard.metainfo.xml
#
# from their checked-in templates:
#   data/dev.bragefuglseth.Fretboard.desktop.in.in
#   data/dev.bragefuglseth.Fretboard.metainfo.xml.in.in
set -euo pipefail

cd "$(dirname "$0")/.."

app_id="dev.bragefuglseth.Fretboard"
data_dir="data"
po_dir="po"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# Step 1: substitute the meson-style @variable@ placeholders. There is only
# one of each here (@icon@, @app-id@), so plain sed stands in for meson's
# configure_file the same way data/meson.build's own appstream path does.
sed "s/@icon@/${app_id}/g" \
  "${data_dir}/${app_id}.desktop.in.in" \
  > "${tmp_dir}/${app_id}.desktop.in"

sed "s/@app-id@/${app_id}/g" \
  "${data_dir}/${app_id}.metainfo.xml.in.in" \
  > "${tmp_dir}/${app_id}.metainfo.xml.in"

# Step 2: merge every po/*.po translation into the substituted templates,
# the same two msgfmt invocations data/meson.build's i18n.merge_file targets
# make under the hood.
msgfmt --desktop \
  --template="${tmp_dir}/${app_id}.desktop.in" \
  -d "${po_dir}" \
  --output-file="${data_dir}/${app_id}.desktop"

msgfmt --xml \
  --template="${tmp_dir}/${app_id}.metainfo.xml.in" \
  -d "${po_dir}" \
  --output-file="${data_dir}/${app_id}.metainfo.xml"

echo "Merged po/*.po into ${data_dir}/${app_id}.desktop and ${data_dir}/${app_id}.metainfo.xml"
