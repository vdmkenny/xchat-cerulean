#!/bin/bash
#
# Signs the app ad-hoc from the inside out. Nested code has to be signed
# before its container, and codesign --deep does not reliably reach libraries
# in Contents/libs, which leaves dyld killing the process at load with
# "Code Signature Invalid".
#
# Usage: tools/sign_app.sh "path/to/XChat Cerulean.app"

set -euo pipefail

APP="${1:?usage: sign_app.sh <app bundle>}"

if [ -d "$APP/Contents/libs" ]; then
    find "$APP/Contents/libs" -type f -name '*.dylib' -print0 \
        | xargs -0 -I {} codesign --force --sign - --timestamp=none {}
fi

for plugin in "$APP"/Contents/PlugIns/*.bundle; do
    [ -d "$plugin" ] || continue
    codesign --force --sign - --timestamp=none "$plugin"
done

codesign --force --sign - --timestamp=none "$APP"

codesign --verify --strict --verbose=2 "$APP"
echo "signed $APP"
