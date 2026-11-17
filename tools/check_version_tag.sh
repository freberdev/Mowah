#!/bin/sh
# Stops a release whose tag does not match the version in windows/Cargo.toml,
# which is where both apps take their version from.
#
# Usage: tools/check_version_tag.sh v1.1.0
set -eu
cd "$(dirname "$0")/.."

tag="${1:?usage: check_version_tag.sh TAG}"
version="$(sed -n 's/^version = "\(.*\)"$/\1/p' windows/Cargo.toml | head -n 1)"
if [ "v$version" != "$tag" ]; then
    echo "Tag $tag does not match version $version in windows/Cargo.toml" >&2
    exit 1
fi
echo "Tag $tag matches version $version"
