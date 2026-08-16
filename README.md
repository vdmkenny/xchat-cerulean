# XChat Cerulean

A native IRC client for macOS, built for Apple Silicon.

Cerulean is a desktop IRC client: tabbed channels and private messages,
a server list with the major networks built in, TLS, DCC file transfers,
logging, notifications with inline replies, and scripting through Perl,
Tcl and Ruby plugins. It is a Cocoa application, not a web app in a
wrapper.

## This is a fork

Cerulean is a fork of [X-Chat Aqua](https://github.com/xchataqua/xchataqua),
the long-running Cocoa front-end for XChat. Upstream stopped in 2017 and no
longer compiles: it expects a 2013 snapshot of glib, OpenSSL 1.0, CocoaPods,
and a crash reporter that was switched off in 2020. This fork rebuilds it on
current foundations so it keeps working on modern hardware. It is not
endorsed by, affiliated with, or supported by the original authors, and bugs
here should be reported here rather than upstream.

## Getting started

Download the latest build from
[Releases](https://github.com/vdmkenny/xchat-cerulean/releases/latest),
unzip it and drag it to Applications. Everything it needs is inside the app.

It is signed ad-hoc rather than with a Developer ID, so the first launch
needs Control-click → Open, or:

```bash
xattr -dr com.apple.quarantine "/Applications/XChat Cerulean.app"
```

### Building it yourself

You need Xcode and [Homebrew](https://brew.sh).

Install the libraries:

```bash
brew install glib gettext openssl@3
```

Clone and build:

```bash
git clone https://github.com/vdmkenny/xchat-cerulean.git
cd xchat-cerulean
xcodebuild -project XChatAqua.xcodeproj -scheme 'XChat Cerulean' -configuration Release -derivedDataPath build build
```

### Keychain prompts while developing

Passwords live in the login keychain. "Always Allow" is bound to the exact
signature that was granted it, and an ad-hoc signature is different on every
build, so each rebuild makes macOS ask again. Create a fixed identity once:

```bash
tools/make_signing_identity.sh
```

then build with it:

```bash
xcodebuild -project XChatAqua.xcodeproj -scheme 'XChat Cerulean' -configuration Release CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" XA_CODE_SIGN_IDENTITY="XChat Cerulean Local Signing" build
```

Released builds are signed ad-hoc, so they ask once per password after each
update.

Open it:

```bash
open "build/Build/Products/Release/XChat Cerulean.app"
```

Move that `.app` to `/Applications` if you want to keep it.

On first launch you get the network list. Pick a network, set a nickname,
and connect. Libera.Chat and Undernet use TLS by default.

If your Homebrew is not in `/opt/homebrew` (an Intel install, or a custom
prefix), pass it in:

```bash
xcodebuild -project XChatAqua.xcodeproj -scheme 'XChat Cerulean' HOMEBREW_PREFIX=/usr/local build
```

## Your files

Settings and logs:

```
~/Library/Application Support/XChat Cerulean/
```

Received files land in `~/Downloads`.

Cerulean does not read X-Chat Aqua's or XChat Azure's old configuration
directories. To bring settings across, copy the old folder to the path above
before you launch it for the first time.

## What is different from X-Chat Aqua

Briefly: it is arm64 native and targets macOS 26, the vendored glib and
OpenSSL 1.0 are replaced by Homebrew glib 2.88 and OpenSSL 3, CocoaPods is
gone, TLS now sends SNI and verifies the certificate hostname, and
notifications are rebuilt on the current API. The GTK and terminal
front-ends, the abandoned iOS port and the Python 2 plugin are removed.

[CHANGELOG.md](CHANGELOG.md) has the full list, including the bugs fixed
along the way.

## A note on how this was built

This port was carried out using an LLM (Claude). The app builds, launches and
connects, but it has not had the long-tail human testing the original
accumulated over the years. Treat it as you would any large automated
refactor, and please report what you find.

## Licence and credits

XChat Cerulean is licensed under the **GNU General Public License, version 2
or later**, the same terms it inherited. See [COPYING](COPYING).

It stands on other people's work:

- **XChat**, © 1998-2010 Peter Zelezny and contributors. The IRC engine.
- **X-Chat Aqua**, © 2002-2013 Steve Green and contributors, with later
  maintenance by Jeong YunWon and others. The Cocoa front-end this forks.
- Further contributions from Camillo Lugaresi, Terje Bless, Eugene Pimenov
  and others named in the source headers.
- **Solarized** colour theme, © Ethan Schoonover.

Modifications for Cerulean are © 2026 its contributors, under the same
licence.

glib (LGPL-2.1-or-later), gettext (LGPL-2.1-or-later) and OpenSSL
(Apache-2.0) are linked from Homebrew when you build from source. The
released binaries carry unmodified copies inside the app bundle, under
`Contents/libs`, so they run without Homebrew installed; each remains under
its own licence.

The Ruby and Tcl scripting plugins link the frameworks that ship with macOS.
Apple has marked both as deprecated, so those two plugins will stop loading
whenever the frameworks are finally removed.
