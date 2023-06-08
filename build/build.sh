#!/bin/bash

set -e

ver="$1"

dir="$(realpath "$(dirname "$(realpath "$0")")/..")"
kbakdir="$dir/src"

tempkbak="$(mktemp -d)"
cp -r "$kbakdir"/* "$tempkbak/"

if [ -z "$ver" ]; then
    kbakver="$(cat "$tempkbak/kbak" | grep -oP "(?<=myver=').*(?=')")"
else
    sed -i -r "s/myver='.*?'/myver='$ver'/" "$tempkbak/kbak"
    kbakver="$ver"
fi

targetdir="$dir/builds/$kbakver"

curdate="$(date -u +'%Y-%m-%d')"

todaysecs=$(($(date -u +'%s') - $(date -u -d "$curdate" +'%s')))

packver="$kbakver~$curdate-$todaysecs"

targetdeb="kbak-$packver.deb"
targetgz="kbak-$packver.tar.gz"

tempdir="$(mktemp -d)"
cp -r "$dir/deb/package/"* "$tempdir/"

sed -i -r "s/Version: .*/Version: $packver/" "$tempdir/DEBIAN/control"

mkdir -p "$tempdir/usr/bin/"
cp "$tempkbak/kbak" "$tempdir/usr/bin/"

mkdir -p "$targetdir"
dpkg-deb --build "$tempdir" "$targetdir/$targetdeb" 1>/dev/null

tar -czPf "$targetdir/$targetgz" --transform 's#^.*/#kbak/#' "$tempkbak"/*

[ -d "$tempdir" ] && rm -r "$tempdir"
[ -d "$tempkbak" ] && rm -r "$tempkbak"

echo "$targetdir/$targetgz $targetdir/$targetdeb"
