# Sol Lite

![Header](Header.jpg)

Sol Lite is a minimal macOS launcher forked from [ospfranco/sol](https://github.com/ospfranco/sol).

This fork keeps Sol's fast native launcher core and removes bundled extras that duplicate dedicated tools.

## Scope

Kept:

- App search
- Custom scripts and links
- Process killer
- Utility actions such as UUID, NanoID, JSON formatting, math, Wi-Fi, IP, theme switching, and symlinks

Removed:

- Calendar
- Translation
- Clipboard manager
- Emoji picker
- Scratchpad
- Browser bookmarks
- Window management
- Media key forwarding
- In-app updater
- Telemetry and crash reporting
- Sparkle/update checks
- About/developer credits screen
- Quit command

## Hotkeys

The app is installed as `Sol Lite.app`.

Native hotkey: `cmd+s`. No Hammerspoon or skhd dependency is required.

This build also removes Sol's quit action and no-ops the native quit bridge so accidental `cmd+q` does not close the launcher.

## Download

Download the latest `.dmg` from GitHub Releases.

## Build

Requirements:

- macOS
- Xcode 16+
- Bun
- Homebrew Ruby
- CocoaPods

```sh
bun install
env PATH="/opt/homebrew/opt/ruby/bin:$PATH" bundle exec pod install --project-directory=macos
xcodebuild -workspace macos/sol.xcworkspace \
  -scheme debug \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=''
```

The built app is produced at:

```txt
~/Library/Developer/Xcode/DerivedData/.../Build/Products/Release/sol.app
```

Rename/sign/package it as `Sol Lite.app` for distribution.

## Upstream

This project is an independent lightweight fork of Sol. Upstream project, copyright, and MIT license remain credited to Oscar Franco and contributors.

## License

MIT License

