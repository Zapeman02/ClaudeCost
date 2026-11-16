#!/bin/zsh
# Runs every check: unit tests, then a full build of the app and widget.
set -e
cd "$(dirname "$0")"
swift test
./build.sh
