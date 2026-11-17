#!/bin/sh
# Builds Mowah for Mac, for both Apple silicon and Intel, and puts the result
# in dist/Mowah-mac.zip at the top of the repository.
# Needs: Xcode and XcodeGen.
set -eu
cd "$(dirname "$0")"

# One version for both apps; it lives in the Windows project's Cargo.toml.
version="$(sed -n 's/^version = "\(.*\)"$/\1/p' ../windows/Cargo.toml | head -n 1)"
year="$(date +%Y)"
# Which certificate signs the app, in this order:
#   1. the environment variable MOWAH_SIGN_IDENTITY, for a release build;
#   2. the first line of signing-identity.local next to this script, for builds
#      on a developer's own Mac. The file is not kept in git;
#   3. "-", which signs the app to run locally only. macOS then treats every
#      build as a new app and asks for the Accessibility permission again.
identity="${MOWAH_SIGN_IDENTITY:-}"
if [ -z "$identity" ] && [ -f signing-identity.local ]; then
    identity="$(head -n 1 signing-identity.local)"
fi
identity="${identity:--}"
# Apple only notarises an app whose signature carries a timestamp from Apple's
# server. Local builds do without, so they also work offline.
case "$identity" in
    "Developer ID"*) timestamp="--timestamp" ;;
    *) timestamp="" ;;
esac

xcodegen generate --quiet
xcodebuild -project Mowah.xcodeproj -scheme Mowah -configuration Release \
    -derivedDataPath build -quiet \
    ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
    MARKETING_VERSION="$version" MOWAH_BUILD_YEAR="$year" \
    CODE_SIGN_IDENTITY="$identity" OTHER_CODE_SIGN_FLAGS="$timestamp" \
    build

mkdir -p ../dist
rm -f ../dist/Mowah-mac.zip
ditto -c -k --keepParent build/Build/Products/Release/Mowah.app ../dist/Mowah-mac.zip
ls -l ../dist/Mowah-mac.zip
