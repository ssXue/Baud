# CLAUDE.md

This file provides guidance for Claude Code when working with this project.

## Project Overview

**Baud** is a macOS native serial port debugging tool built with SwiftUI. It supports:
- Serial terminal with HEX/ASCII display and real-time oscilloscope
- SLCAN (CAN bus) debugging with frame tracing, monitoring, and stability analysis
- Data recording and playback with session management
- DBC file import for signal extraction

## Build & Run

```bash
swift build                      # SPM build
swift test                       # Run unit tests (113 tests, 14 suites)
swift build 2>&1 | grep error    # Check errors only
./build-app.sh --run             # Wrap into .app bundle and launch
```

- `build-app.sh` creates `.build/arm64-apple-macosx/debug/Baud.app` — required for localization resources
- `package.sh` builds release DMG for distribution
- Requires macOS 26 (Tahoe), Xcode 26, Swift 6.2

## Architecture

```
Baud (app target) → BaudKit (library target)
  Models/        — SerialPortConfig, CANFrame, CANSignal, BaudError, SerialPreset
  Services/      — SerialPortManager, SLCANManager, CANFrameStore, SessionRecorder
  Views/         — Connection, SerialTerminal, SLCANDebugger, Recorder, Shared
  Resources/     — en.lproj / zh-Hans.lproj localization
```

### Environment Objects (DI)

All services registered in `BaudApp.swift`:
`SerialPortManager`, `SerialDataManager`, `SLCANManager`, `CANFrameStore`, `CANSignalStore`, `CANBusAnalyzer`, `SessionRecorder`, `SessionManager`, `CANTxStore`, `SerialPresetStore`, `ProjectManager`

Use `@Environment(Type.self)` for injection, **not** `@EnvironmentObject`.

## Key Conventions

- **SwiftUI**: `@Bindable var x = x` inside `body` for `$` bindings from `@Observable` env objects
- **Toolbars**: Use `Label("text", systemImage:)` for Liquid Glass — no bare `Image`, no `HStack` wrappers
- **Layout**: Golden ratio (0.618 : 0.382) for `HSplitView` panes
- **Auto scroll**: `onScrollPhaseChange` detecting `.interacting` phase (not timer hacks)
- **Localization**: Two locales (`en` + `zh-Hans`), `.lproj/Localizable.strings` files
- **Testing**: Swift Testing framework (`import Testing`, `@Suite`, `@Test`, `#expect`)
- **Persistence**: UserDefaults for settings, JSON files in `~/Library/Application Support/Baud/Sessions/`

## Dependencies

| Library | Purpose |
|---------|---------|
| ORSSerialPort (2.1.0) | USB CDC serial port I/O |
| DGCharts (5.1.0) | Real-time line/bar charts |
| Sparkle (2.6.0+) | Auto-update framework |

## Common Patterns

### Adding a new Environment service
1. Create `@Observable @MainActor public final class FooService`
2. Add `@State private var fooService = FooService()` in `BaudApp`
3. Add `.environment(fooService)` in `ContentView`
4. Access via `@Environment(FooService.self) private var fooService`

### Adding a new test suite
1. Create file in `Tests/BaudKitTests/`
2. Use `import Testing` + `@Suite("Name")` + `@Test("description")`
3. Focus on pure Models/functions — `@MainActor` services need `@MainActor` on test functions

### Error handling
Use `BaudError` enum for all user-facing errors, call `error.showAlert()` in UI layer.
