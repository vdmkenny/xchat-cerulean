#!/bin/bash
#
# Copies the Homebrew libraries the app links into the bundle and rewrites the
# load commands to point at them, so a downloaded build runs without Homebrew
# installed.
#
# Usage: tools/bundle_libs.sh "path/to/XChat Cerulean.app"

set -euo pipefail

APP="${1:?usage: bundle_libs.sh <app bundle>}"
BINARY="$APP/Contents/MacOS/XChat Cerulean"
LIBS="$APP/Contents/libs"

[ -f "$BINARY" ] || { echo "no executable at $BINARY" >&2; exit 1; }
mkdir -p "$LIBS"

# Anything outside these prefixes ships with macOS and is left alone.
external() {
    otool -L "$1" | awk 'NR > 1 { print $1 }' \
        | grep -E '^(/opt/homebrew|/usr/local/opt|/usr/local/Cellar)' || true
}

rewrite() {
    local target="$1" dep name
    while read -r dep; do
        [ -n "$dep" ] || continue
        name="$(basename "$dep")"

        if [ ! -f "$LIBS/$name" ]; then
            cp "$dep" "$LIBS/$name"
            chmod u+w "$LIBS/$name"
            install_name_tool -id "@executable_path/../libs/$name" "$LIBS/$name"
            # A copied library has dependencies of its own.
            rewrite "$LIBS/$name"
        fi

        install_name_tool -change "$dep" "@executable_path/../libs/$name" "$target"
    done < <(external "$target")
}

rewrite "$BINARY"

# Plugins are loaded into the same process, so they resolve against the
# executable too.
for plugin in "$APP"/Contents/PlugIns/*.bundle; do
    [ -d "$plugin" ] || continue
    name="$(basename "$plugin" .bundle)"
    [ -f "$plugin/Contents/MacOS/$name" ] && rewrite "$plugin/Contents/MacOS/$name"
done

remaining="$(external "$BINARY")"
if [ -n "$remaining" ]; then
    echo "still linking outside the bundle:" >&2
    echo "$remaining" >&2
    exit 1
fi

echo "bundled $(ls -1 "$LIBS" | wc -l | tr -d ' ') libraries into $LIBS"
