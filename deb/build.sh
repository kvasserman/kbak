#!/bin/bash

set -e

dir="$(realpath "$(dirname "$(realpath "$0")")/..")"
kbak="$dir/kbak"
targetdir="$dir/builds"

kbakver="$(cat "$kbak" | grep -oP "(?<=myver=').*(?=')")"

curdate="$(date -u +'%Y-%m-%d')"

todaysecs=$(($(date -u +'%s') - $(date -u -d "$curdate" +'%s')))

packver="$kbakver~$curdate-$todaysecs"

echo "Building package for kbak version $packver"

tempdir="$(mktemp -d)"
cp -r "$dir/deb/package/"* "$tempdir/"

sed -i -r "s/Version: .*/Version: $packver/" "$tempdir/DEBIAN/control"

cp "$kbak" "$tempdir/usr/bin/"

mkdir -p "$targetdir"

dpkg-deb -v --build "$tempdir" "$targetdir/kbak-$packver.deb"

echo "Done"
