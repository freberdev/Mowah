#!/bin/sh
# Builds Mowah for Mac, for both Apple silicon and Intel, and puts the result
# in dist/Mowah-mac.zip at the top of the repository.
# Needs: Xcode and XcodeGen.
set -eu
cd "$(dirname "$0")"

# One version for both apps; it lives in the Windows project's Cargo.toml.
version="$(sed -n 's/^version = "\(.*\)"$/\1/p' ../windows/Cargo.toml | head -n 1)"
year="$(date +%Y)"
# "-" signs the app to run locally. Set MOWAH_SIGN_IDENTITY to a Developer ID
# identity to sign it for distribution.
identity="${MOWAH_SIGN_IDENTITY:--}"

xcodegen generate --quiet
xcodebuild -project Mowah.xcodeproj -scheme Mowah -configuration Release \
    -derivedDataPath build -quiet \
    ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
    MARKETING_VERSION="$version" MOWAH_BUILD_YEAR="$year" \
    CODE_SIGN_IDENTITY="$identity" \
    build

mkdir -p ../dist
rm -f ../dist/Mowah-mac.zip
ditto -c -k --keepParent build/Build/Products/Release/Mowah.app ../dist/Mowah-mac.zip
ls -l ../dist/Mowah-mac.zip
