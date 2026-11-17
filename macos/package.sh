#!/bin/sh
# Packs the built Mowah.app into dist/Mowah.dmg at the top of the repository.
# The disk image holds the app next to a shortcut to Applications, which is how
# a Mac user expects to install something: open the image and drag the app over.
#
# Usage: package.sh [SIGNING_IDENTITY]
# With a Developer ID identity the disk image itself is signed as well.
set -eu
cd "$(dirname "$0")"

identity="${1:--}"
app=build/Build/Products/Release/Mowah.app
dmg=../dist/Mowah.dmg

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
# ditto, not cp: it keeps the app's signature and attributes intact.
ditto "$app" "$staging/Mowah.app"
ln -s /Applications "$staging/Applications"

mkdir -p ../dist
rm -f "$dmg"
hdiutil create -quiet -volname Mowah -srcfolder "$staging" -fs HFS+ -format UDZO "$dmg"

case "$identity" in
    "Developer ID"*) codesign --sign "$identity" --timestamp "$dmg" ;;
esac
ls -l "$dmg"
