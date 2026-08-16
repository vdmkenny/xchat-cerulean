# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [2.3.2] - 2026-08-16

### Fixed

- **Clicking a link in the conversation killed the app.** The handler picks a
  command per kind of word, and for a URL it stopped setting one when links
  started being followed natively, but still fell through to the code that
  runs it, which took the length of a null pointer. Any link would do it, and
  it had been that way since 2017.
- **Ruby scripts could not require anything.** The embedded interpreter was
  started without its load path, so it began with an empty one. A file
  listing the paths was meant to make up for that, but it was generated when
  the app was built and then looked for under a directory that exists
  nowhere, which is what the warning on startup was about. The interpreter
  now fills the path in from its own configuration.
- **The perl bridge was never built.** Three perl scripts shipped with
  nothing able to run them. It builds against the perl on the machine and is
  included now.

Neither interpreter is carried in the app. Both bind to what the system
already provides, as they always did.

## [2.3.1] - 2026-08-16

### Fixed

- **A file link could claim to be something it was not.** 2.3.0 showed any
  file URL as its last path component, so a message from anybody could carry
  a link reading `photo.jpg` that pointed elsewhere, and following it hands
  the target to the system to open. A local path is linked only when it names
  something in the download directory, which is what the transfer completion
  line points at. Every other one is left as plain text.
- **Two string appends could run past their buffer.** The `ISON` builder
  checked how full its buffer was only after adding a name, by which point a
  name near the length limit could already have written past the end. And the
  DCC resume request held back ten bytes for the passive id it appends, which
  is not enough for a space, a sign, ten digits and a terminator; the id
  comes from the offer, so the sender chooses it.

### Changed

- The window opens at a size that fits the channel sidebar, a conversation
  and the user list at once. It was 640x400, which fits none of them. This
  applies to a fresh configuration; an existing one keeps its own size.

## [2.3.0] - 2026-08-16

### Added

- **IPv6 is preferred, with IPv4 as the fallback.** Connections walked the
  resolver's list in whatever order it came back, which puts IPv6 first only
  on a host with a global IPv6 address and a resolver that applies RFC 6724.
  Every IPv6 address is now tried before any IPv4 one.
- **DCC works over IPv6.** The address in an offer is a 32 bit number, which
  a sender with no IPv4 cannot express, so it sends a literal address
  instead, as other clients do. That is now recognised and the transfer
  connects over IPv6. Proxied transfers stay IPv4 only, since the proxy
  types this client speaks cannot do anything else.
- **The received file is a link.** The completion line named the file but
  gave no way to open it. The name is now clickable, with the full path in
  a tooltip. A name containing spaces survives, since the underlying URL is
  percent encoded.
- **Transfers are easy to reach:** a toolbar button, a keyboard shortcut,
  and a Dock menu entry that shows how many are running.
- **Transfers keep the machine awake.** A transfer is network and disk
  activity with no user input, so the system was free to idle sleep partway
  through one and cut the connection. Display sleep is still allowed.
- **A change of network is noticed.** Sleep and wake were handled, but a
  Wi-Fi hop, a VPN going up or down, or an Ethernet cable being plugged in
  left sockets on a route that no longer worked, with nothing noticing until
  the ping timeout expired. Servers waiting to reconnect are retried at once
  and the ones still up are pinged.

### Fixed

- **Waking could connect twice.** The wake handler cleared the reconnect
  timer's tag without cancelling the timer, so a retry already scheduled
  still fired after the connection had been re-established.
- The Changelog and licence links on the site pointed at a branch name that
  no longer exists.

### Changed

- The default branch is `main`.
- The toolbar identifier changed, so that the new button reaches anyone with
  a saved layout. Toolbar customisation is reset once.

## [2.2.1] - 2026-08-16

### Changed

- The timestamp is a size down, dimmer, and no longer bracketed. It sits
  beside the conversation rather than competing with it.

### Fixed

- **A long nick ran over the separator.** 2.2.0 sized the nick column for
  the timestamp but not for the name beside it, and the nick is right
  aligned on the indent, so anything that did not fit spilled past it. The
  column grows to the widest nick seen.
- The release job failed to publish the update feed the first time. It
  tested for changes before staging the file, and a file that is new to the
  tree shows no difference, so the very first publication was skipped.

## [2.2.0] - 2026-08-16

### Added

- **IRCv3 capabilities.** 2.1.0 added SASL; the negotiation now covers the
  rest of what this client can act on.
  - `message-tags`, the tag section ahead of a line, with the escaping the
    specification lays out.
  - `server-time`, so a message is shown as having happened when the server
    saw it. Reconnects and bouncer playback stop being stamped with the
    moment you reconnected.
  - `multi-prefix`, so a user's full set of modes is known rather than only
    the highest.
  - `away-notify` and `chghost`, so who is away and whose host changed is
    right between name replies instead of going stale until the next `WHO`.

  `extended-join` and `account-notify` are deliberately not requested.
  Neither carries anything this client can use, and `extended-join` moves the
  channel out of the trailing parameter of `JOIN`, which the parser relies
  on.
- **Automatic updates.** Nothing told anyone a new version existed. Sparkle
  checks a signed feed published with the site, once a day and from **Check
  for Updates** in the application menu. Whether it looks on its own is a
  preference under Other. The dialog shows that version's changelog.
- **A finished download says so**, with a button that opens the Finder on the
  file.

### Changed

- Notifications from one conversation share a thread, so several arriving
  together stack into a group rather than a column of banners.
- Being addressed directly or offered a file is marked time sensitive, so a
  Focus lets those through while ordinary traffic waits.

### Fixed

- A timestamp format wider than the nick column ran over the separator and
  into the message. The column grows to fit whatever format is set.

## [2.1.0] - 2026-08-16

### Added

- **SASL authentication.** xchat's capability negotiation predates IRCv3: it
  asked only for `identify-msg`, a freenode extension, and there was no way
  to authenticate before registration finished, which is why a registered
  nick was greeted with a request to identify. SASL PLAIN is implemented
  against the IRCv3 3.1 specification and turned on per network under
  Network details.
- **Auto-accept for senders you name.** Accepting transfers was a single
  switch covering everyone: off, ask, or take a file from anybody, which is
  why leaving it on was a bad idea. Senders listed under File transfers are
  accepted straight away and every other offer still prompts. Entries are
  nick masks, so `*Search*` covers a bot whose name carries a suffix.
- **Unread counts in the sidebar.** A tab with something waiting only
  changed the colour of its name, which says there is something but not how
  much. Rows carry a count now. Messages and mentions count; joins and parts
  do not, and selecting the tab clears it.
- `tools/make_signing_identity.sh`, which creates a self-signed identity for
  local builds. A keychain grant is bound to the signature that received it
  and an ad-hoc signature differs on every build, so rebuilding meant being
  asked for permission again each time.

### Changed

- **Passwords live in the login keychain**, one entry per network and kind,
  rather than in `servlist_.conf` in the clear. A configuration still
  holding them is read as before and the secrets move across on the next
  save, which is also when they stop being written to disk.

### Security

- Server and NickServ passwords are no longer stored in plaintext on disk.
- `PASS` is not sent when SASL is in use. It handed the server the same
  secret a second time, outside the authentication exchange.

## [2.0.1] - 2026-08-16

### Changed

- **The default network list was rebuilt and every entry tested.** It was
  still xchat's from around 2010: 85 networks, most long gone. 2.0.0 only
  renamed freenode to Libera.Chat rather than replacing the list. There are
  23 networks now, each checked by connecting to it, and 20 of them use TLS.
  Undernet, QuakeNet and GameSurge offer no TLS port at all and stay
  plaintext.
- The category list in Settings is a full-height source list on the same
  material as the channel list, with a symbol per pane. The pane name moved
  to the window subtitle, since it repeated the heading below it.
- Buttons the nibs left touching are spaced apart, anchored to whichever
  edge of their container they sit closest to.
- Menus and help links carry this project's name and address rather than
  X-Chat Aqua's.

### Fixed

- **The Undernet entry claimed TLS on a port with nothing listening**, so
  anyone starting from the built-in list could not connect to it.
- **A stalled connection worker could hang the interface for good.** Reading
  its pipe blocks the main thread a byte at a time; each byte now waits on a
  bounded poll. The buffer is terminated on entry as well, because the
  caller switches on its first character without checking the read
  succeeded. Upstream issue 40.
- **macOS text substitutions corrupted input.** Smart quotes break a quoted
  command argument, dash substitution turns `--flag` into an em dash, and
  text replacement expands snippets inside nicks and URLs. All three are off
  in the input field. Upstream issues 155 and 219.
- The nick separator sat an inset's width left of the gap it marks, because
  it is drawn in view coordinates while the indent is measured inside the
  text container. Dragging it was off by the same amount.
- Sidebar symbols drew black on the dark sidebar. A template image drawn
  directly is not tinted, so the row's colour is baked in.
- The dock badge never counted anything: no events were marked worth
  alerting on unless a configuration already existed, which is never true on
  a first run.
- The chat view asked for an image that went away when the status bullets
  became drawn orbs, warning on every launch.

### Removed

- `new_version_alert`, which had no callers and belonged to the crash
  reporter that went in 2.0.0. Upstream issue 217 does not apply.

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

- **The whole interface was rebuilt on stock AppKit.** The nibs positioned
  every control at a fixed frame, which left the windows cramped and without
  margins. Rows and columns are stack views now, lists are borderless with
  current row metrics, and columns are at least as wide as their headings.
- **The channel list and user list are vibrant sidebars**, each with a
  toolbar toggle above the pane it hides and a tracking separator aligned to
  the divider. The user list toggle is disabled outside a channel.
- **Colours follow the system appearance.** Dark and light mode both work;
  nothing is hard-coded to a light palette.
- **The window has a toolbar** with SF Symbols for the sidebars, networks,
  joining a channel, the channel list, search and settings.
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
- **Accepting an offered file did nothing.** The confirmation sheet captured
  an object that released itself when answered, so the object was freed
  twice and the answer was lost.
- **The chat colours froze to whichever appearance the app first ran under.**
  Saving the palette wrote what the semantic text colours resolved to, so a
  first run in dark mode left the conversation black in light mode.
- The dialog buttons in a private message tab were wired to a method that
  does not exist, so clicking one did nothing.

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
- The **tab bar** channel switcher and the preference that selected it. It
  was the pre-Auto-Layout path and rendered no tabs at all, so the sidebar
  is now the only switcher. `SGWrapView` and `CLTabViewButtonCell` went with
  it.

### Security

- TLS certificates are now bound to the hostname dialled (see Added).
- Shell command construction from filenames removed from plugin installation.
- The dead Crashlytics API key is no longer shipped.

[2.0.0]: https://github.com/vdmkenny/xchat-cerulean/releases/tag/2.0.0
[2.0.1]: https://github.com/vdmkenny/xchat-cerulean/releases/tag/2.0.1
[2.1.0]: https://github.com/vdmkenny/xchat-cerulean/releases/tag/2.1.0
[2.2.0]: https://github.com/vdmkenny/xchat-cerulean/releases/tag/2.2.0
[2.2.1]: https://github.com/vdmkenny/xchat-cerulean/releases/tag/2.2.1
