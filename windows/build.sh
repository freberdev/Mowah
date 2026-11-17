#!/bin/sh
# Cross-compiles Mowah for Windows from macOS or Linux and puts the result in dist/
# at the top of the repository.
# Needs: rustup with the x86_64-pc-windows-gnu target, and mingw-w64.
set -eu
cd "$(dirname "$0")"

# Homebrew installs rustup without putting it on PATH.
if [ -d /opt/homebrew/opt/rustup/bin ]; then
    PATH="/opt/homebrew/opt/rustup/bin:$PATH"
fi

cargo build --release --target x86_64-pc-windows-gnu
mkdir -p ../dist
cp target/x86_64-pc-windows-gnu/release/mowah.exe ../dist/Mowah.exe
ls -l ../dist/Mowah.exe
