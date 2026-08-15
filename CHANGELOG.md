# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [2.0.0] - 2026-08-15

First release of the fork. X-Chat Aqua's last release was 1.18.11 in 2017;
the version restarts at 2.0.0 to mark the rebrand and the fact that almost
every dependency underneath the app was replaced.

The client is now **XChat Cerulean**, and runs natively on Apple Silicon.

### Added

- Server Name Indication (SNI) on TLS connections. Without it, modern IRC
  networks return a certificate for the wrong host, or refuse the handshake.
- Certificate hostname verification. Previously a certificate valid for *any*
  host was accepted, which made TLS useless against an active attacker.
  Networks marked "accept invalid certificates" still bypass this by choice.
- TLS enabled by default for Libera.Chat and Undernet, on port 6697.
- A `flags` column in the built-in network list so networks can default to TLS.
- `Branding.h`, a single definition point for the product name, bundle
  identifier and homepage.
- `Dependencies.xcconfig`, so the Homebrew prefix can be overridden with
  `HOMEBREW_PREFIX=...` rather than edited into the project.

### Changed

- **Rebranded** from X-Chat Aqua to XChat Cerulean. Settings now live in
  `~/Library/Application Support/XChat Cerulean/`; the old directory is not
  read automatically.
- **glib**: dropped the vendored 2013 fork of glib 2.35 in favour of Homebrew
  glib 2.88. The xchat core needed no changes to compile against it.
- **OpenSSL**: moved from 1.0 to 3.x, porting off the `SSL`, `SSL_CTX`,
  `SSL_SESSION` and `X509` structs that became opaque in 1.1.
- **Minimum TLS version** raised to 1.2.
- **Notifications** rewritten on `UNUserNotificationCenter`;
  `NSUserNotification` was removed by Apple. Inline replies still work.
- **DCC transfer rates** now measured with `g_get_monotonic_time()` instead of
  the deprecated `GTimeVal`, so a clock change no longer skews them.
- **Build**: arm64, deployment target macOS 26, ad-hoc signing, no sandbox.
- Default network list refreshed. freenode collapsed in 2021 and is replaced
  by Libera.Chat.
- Plugin installation uses `NSFileManager` rather than `system()`.
- Log files open in the user's chosen handler instead of always TextEdit.

### Fixed

- **A 64-bit bug in the threaded connect path.** `pthread_create` wrote a
  `pthread_t *` into an `int`, truncating it, and that value was then passed
  to `kill()` and `waitpid()`. The pointer was also leaked. The thread is now
  stored properly and cancelled and joined on teardown.
- **A build race.** The `xchat` target did not depend on `Prebuild`, so it
  compiled in parallel with the script that rewrites `build_number.h` and
  `config.package_name.in.h`, producing intermittent failures against a
  half-written header. The dependency is declared and the header is written
  atomically.
- **A per-connection memory leak.** The connect worker only freed its
  hostname buffers under Windows, on the assumption that the process was
  exiting; on macOS that code runs as a thread, so it leaked on every attempt.
- A crash on launch from calling `setenv()` with a NULL value when no CA
  bundle is present.
- `strncpy` into a fixed buffer without termination in the notification path.
- The default-network selection compared a hardcoded `g_str_hash` value and
  silently stopped matching whenever the network was renamed.

### Removed

- **CocoaPods**, and with it Fabric and Crashlytics — a crash-reporting
  service shut down in 2020, whose API key was committed in `Info.plist`.
- The **GTK** and **terminal** front-ends.
- The abandoned **iOS** project.
- The **Python** plugin. It targets the Python 2 C API, and
  `Python.framework` no longer ships with macOS.
- The **XChat Azure** Mac App Store target and its sandbox entitlements.
- 103MB of vendored **Perl 5.10-5.18 headers**, unreferenced by the build.
- A stale absolute reference to `/usr/local/etc/openssl/cert.pem`.

### Security

- TLS certificates are now bound to the hostname dialled (see Added).
- Shell command construction from filenames removed from plugin installation.
- The dead Crashlytics API key is no longer shipped.

[2.0.0]: https://github.com/vdmkenny/xchataqua/releases/tag/v2.0.0
