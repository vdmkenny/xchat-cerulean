# XChat Cerulean

An IRC client for macOS, native and Apple Silicon only.

Cerulean is a fork of [X-Chat Aqua](https://github.com/xchataqua/xchataqua),
the Cocoa front-end for XChat. Upstream stopped moving in 2017 and no longer
builds: it wanted a 2013 snapshot of glib, OpenSSL 1.0, CocoaPods, and a
Crashlytics SDK that was switched off in 2020. With Apple winding down Intel
support, an Intel-only client that cannot be compiled is a client that
quietly disappears. This fork exists so it does not.

> **Disclosure:** this port was carried out using an LLM (Claude). Treat the
> changes as you would any large automated refactor: the app builds, launches
> and connects, but it has not been through the kind of long-tail human
> testing the original had. Bug reports welcome.

## What changed

**It builds on a current Mac.** arm64 native, macOS 26 (Tahoe) deployment
target, current Xcode.

**Modern libraries instead of vendored ones.** The 13-year-old bundled glib
fork is gone in favour of Homebrew's glib 2.88. OpenSSL 1.0 became OpenSSL 3,
which meant porting the code off the now-opaque `SSL`, `SSL_CTX` and `X509`
structs.

**CocoaPods is gone.** Fabric and Crashlytics were dead services; the only
thing still needed from the pods was two debug macros, which are now a single
local header. Building needs Xcode and Homebrew, nothing else.

**TLS actually works, and actually verifies.** The old code sent no SNI, so
modern IRC networks handed back the wrong certificate or refused the
handshake. It also never checked that the certificate matched the host you
dialled, so a valid certificate for any domain would have passed. Both are
fixed, and the TLS floor is now 1.2. Libera.Chat and Undernet default to TLS.

**Notifications work again.** `NSUserNotification` was removed by Apple;
Cerulean uses `UNUserNotificationCenter`, including inline replies.

**A pile of dead weight removed.** The GTK and terminal front-ends, the
abandoned iOS port, the Python 2 plugin, and 103MB of vendored Perl headers.

See [CHANGELOG.md](CHANGELOG.md) for the full list, including the bug fixes
found along the way.

## Building

Requires Xcode and [Homebrew](https://brew.sh).

```bash
brew install glib gettext openssl@3
```

```bash
git clone https://github.com/vdmkenny/xchataqua.git
cd xchataqua
xcodebuild -project XChatAqua.xcodeproj -scheme 'XChat Cerulean' -configuration Release build
```

The built app lands in Xcode's DerivedData; `-derivedDataPath build` will put
it somewhere more predictable instead.

If your Homebrew lives outside `/opt/homebrew`, override the prefix:

```bash
xcodebuild -project XChatAqua.xcodeproj -scheme 'XChat Cerulean' HOMEBREW_PREFIX=/usr/local build
```

## Where your files live

Settings and logs:

```
~/Library/Application Support/XChat Cerulean/
```

Cerulean does not read X-Chat Aqua's or XChat Azure's old configuration
directories. To carry settings over, copy the old folder to the path above
before first launch.

## Licence and credits

XChat Cerulean is licensed under the **GNU General Public License, version 2
or later** — the same terms it inherited. See [COPYING](COPYING).

It stands on other people's work:

- **XChat** — © 1998-2010 Peter Zelezny and contributors. The IRC engine.
- **X-Chat Aqua** — © 2002-2013 Steve Green and contributors, with later
  maintenance by Jeong YunWon and others. The Cocoa front-end this forks.
- Additional contributions from Camillo Lugaresi, Terje Bless,
  Eugene Pimenov, and others named in the source headers.
- **Solarized** colour theme — © Ethan Schoonover.

Modifications for Cerulean are © 2026 its contributors, under the same
licence. This is a fork; it is not endorsed by, affiliated with, or supported
by the original authors.

Third-party libraries are linked, not vendored: glib (LGPL-2.1-or-later) and
OpenSSL (Apache-2.0) come from Homebrew and are not redistributed here.
