# Sol Lite

Sol Lite is a native Swift/AppKit macOS launcher fork inspired by [ospfranco/sol](https://github.com/ospfranco/sol).

This branch removes the React Native, JavaScript, CocoaPods, Sparkle, and Sentry stack. The app is offline-first and ships as one small AppKit bundle.

## Scope

Kept for native v1:

- App search from `/Applications`, `/System/Applications`, and `~/Applications`
- User scripts from `~/.config/sol/scripts` (`.sh`, `.applescript`, `.scpt`)
- Process killer
- Native `cmd+s` launcher hotkey
- Accidental quit protection

Removed:

- React Native, JavaScript, Hermes, Metro, Bun runtime, CocoaPods
- Calendar, translation, clipboard manager, emoji picker, scratchpad
- Browser bookmarks, file indexer, window management, media key forwarding
- In-app updater, Sparkle/update checks, telemetry/crash reporting
- About/developer credits screen and quit command

## Build

Requirements:

- macOS
- Xcode command line tools

```sh
native/SolLite/build.sh
```

The built app is produced at:

```txt
native/SolLite/build/Sol Lite.app
```

Install locally:

```sh
rm -rf '/Applications/Sol Lite.app'
cp -R 'native/SolLite/build/Sol Lite.app' '/Applications/Sol Lite.app'
open -a 'Sol Lite'
```

## Upstream

This project is an independent lightweight native fork of Sol. Upstream project, copyright, and MIT license remain credited to Oscar Franco and contributors.

## License

MIT License

