#!/bin/sh
# Builds Mowah for Mac the way it is handed to other people: signed with a
# Developer ID, notarised by Apple, and with Apple's approval stapled to the
# app so it opens without a warning even offline. The result replaces
# dist/Mowah-mac.zip at the top of the repository.
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
zip=../dist/Mowah-mac.zip

./build.sh

echo "Sending the app to Apple. This usually takes a few minutes."
result="$(xcrun notarytool submit "$zip" --keychain-profile "$profile" --wait --output-format json)"
status="$(printf '%s' "$result" | sed -n 's/.*"status" *: *"\([^"]*\)".*/\1/p')"
id="$(printf '%s' "$result" | sed -n 's/.*"id" *: *"\([^"]*\)".*/\1/p')"
if [ "$status" != "Accepted" ]; then
    echo "Apple did not accept the app (status: ${status:-unknown}). Their log:" >&2
    [ -n "$id" ] && xcrun notarytool log "$id" --keychain-profile "$profile" >&2
    exit 1
fi

# The approval is attached to the app itself, so the zip has to be made again.
xcrun stapler staple "$app"
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"

spctl --assess --type execute --verbose=2 "$app"
ls -l "$zip"
