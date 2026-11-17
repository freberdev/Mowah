#!/bin/sh
# Builds Mowah for Mac the way it is handed to other people: signed with a
# Developer ID and notarised by Apple, with Apple's approval stapled both to
# the app and to the disk image, so that either opens without a warning even
# offline. The result replaces dist/Mowah.dmg at the top of the repository.
#
# Needs, besides what build.sh needs:
#   MOWAH_SIGN_IDENTITY   the full name of a "Developer ID Application" certificate
#                         in the keychain
#   a keychain profile with the notarisation credentials, created once with
#   `xcrun notarytool store-credentials`. Its name is taken from
#   MOWAH_NOTARY_PROFILE and is "mowah-notary" if that is not set.
set -eu
cd "$(dirname "$0")"

case "${MOWAH_SIGN_IDENTITY:-}" in
    "Developer ID Application:"*) ;;
    *)
        echo "Set MOWAH_SIGN_IDENTITY to a Developer ID Application certificate." >&2
        exit 1
        ;;
esac
profile="${MOWAH_NOTARY_PROFILE:-mowah-notary}"
app=build/Build/Products/Release/Mowah.app
dmg=../dist/Mowah.dmg

# Sends one file to Apple and stops, showing Apple's log, if it is not accepted.
notarise() {
    echo "Sending $(basename "$1") to Apple. This usually takes a few minutes."
    result="$(xcrun notarytool submit "$1" --keychain-profile "$profile" --wait --output-format json)"
    status="$(printf '%s' "$result" | sed -n 's/.*"status" *: *"\([^"]*\)".*/\1/p')"
    id="$(printf '%s' "$result" | sed -n 's/.*"id" *: *"\([^"]*\)".*/\1/p')"
    if [ "$status" != "Accepted" ]; then
        echo "Apple did not accept $(basename "$1") (status: ${status:-unknown}). Their log:" >&2
        [ -n "$id" ] && xcrun notarytool log "$id" --keychain-profile "$profile" >&2
        exit 1
    fi
}

./build.sh

# The app first. Apple takes an app as a zip, and the approval is then stapled
# to the app itself, so a copy dragged out of the disk image carries it along.
upload="$(mktemp -d)"
trap 'rm -rf "$upload"' EXIT
ditto -c -k --keepParent "$app" "$upload/Mowah.zip"
notarise "$upload/Mowah.zip"
xcrun stapler staple "$app"

# Then the disk image, made again so that it holds the stapled app.
./package.sh "$MOWAH_SIGN_IDENTITY"
notarise "$dmg"
xcrun stapler staple "$dmg"

spctl --assess --type execute --verbose=2 "$app"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
ls -l "$dmg"
