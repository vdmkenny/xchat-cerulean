#!/bin/bash
#
# Creates a self-signed code signing identity in the login keychain and
# leaves it there for local builds to use.
#
# Ad-hoc signatures have no stable identity, so every rebuild produces a
# different one and the keychain stops recognising the app: "Always Allow"
# is bound to the signature that was granted it. Signing local builds with a
# fixed identity keeps that grant valid.
#
# This is for development machines. Released builds are signed ad-hoc, which
# is why they ask once per secret after each update.
#
# Usage: tools/make_signing_identity.sh ["Common Name"]

set -euo pipefail

NAME="${1:-XChat Cerulean Local Signing}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "Already present: $NAME"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$WORK/key.pem" -out "$WORK/cert.pem" \
    -subj "/CN=$NAME" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null

# An empty password and OpenSSL 3's defaults both produce a bundle the
# Security framework refuses, so use a throwaway password and the older
# algorithms it accepts.
PASS="transient"
openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
    -out "$WORK/identity.p12" -passout "pass:$PASS" \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 2>/dev/null

# -T codesign lets codesign use the key without asking every time.
security import "$WORK/identity.p12" -k "$KEYCHAIN" -P "$PASS" \
    -T /usr/bin/codesign -T /usr/bin/security >/dev/null

# Without this the key still prompts on each use.
security set-key-partition-list -S apple-tool:,apple: -k "" "$KEYCHAIN" >/dev/null 2>&1 || \
    echo "note: could not set the partition list; codesign may prompt once" >&2

echo "Created: $NAME"
echo
echo "Build with it:"
echo "  xcodebuild -project XChatAqua.xcodeproj -scheme 'XChat Cerulean' \\"
echo "      -configuration Release XA_CODE_SIGN_IDENTITY=\"$NAME\" build"
