#!/bin/zsh
# Builds ClaudeCost.app. `./build.sh install` also copies it to /Applications and launches it.
set -e
cd "$(dirname "$0")"
xcodebuild -project ClaudeCost.xcodeproj -target ClaudeCost -configuration Release -allowProvisioningUpdates SYMROOT="$PWD/build" build | grep -E "error|BUILD"

if [[ "$1" == "install" ]]; then
    pkill -x ClaudeCost || true
    rm -rf /Applications/ClaudeCost.app
    cp -R build/Release/ClaudeCost.app /Applications/
    open /Applications/ClaudeCost.app
fi
