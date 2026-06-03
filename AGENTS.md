# AGENTS.md

This file summarizes key decisions, conventions, and pitfalls discovered during development.

## Build & Run

```bash
swift build                      # SPM build
swift test                       # Run unit tests (79 tests, 8 suites)
swift build 2>&1 | grep error    # Check errors only
./build-app.sh --run             # Wrap into .app bundle and launch (required for localization)
```

- `build-app.sh` creates `.build/arm64-apple-macosx/debug/Baud.app` — SPM bare executable can't find `Bundle.main` resources
- Must re-run `build-app.sh` after any build to pick up resource changes
- `build-app.sh` embeds Sparkle.framework, fixes rpath with `install_name_tool`, and re-signs with `codesign --force --deep --sign -`
- `package.sh` does the same for release builds and creates a DMG

## Dependencies

- **ORSSerialPort** (2.1.0) — IOKit USB CDC serial port discovery and I/O
- **DGCharts** (5.1.0) — ChartsOrg/Charts, real-time line charts via `NSViewRepresentable`
  - Import as `import DGCharts` (renamed from Charts to avoid conflict with Apple Swift Charts)
  - Use `LineChartView` wrapped in `NSViewRepresentable`
  - Must call `chart.notifyDataSetChanged()` + `chart.setNeedsDisplay()` after data updates
  - X-axis formatter: `ChartXAxisFormatter` in `Views/ChartXAxisFormatter.swift`
- **Sparkle** (2.9.2+) — Auto-update framework
  - `SPUStandardUpdaterController` with `startingUpdater: true` in BaudApp
  - "Check for Updates" in Help menu, triggers `updater.checkForUpdates()`
  - `SUFeedURL` points to `raw.githubusercontent.com` (not GitHub Pages — Pages failed with Jekyll)
  - `SUPublicEDKey` in Info.plist, private key in GitHub Secrets `SPARKLE_PRIVATE_KEY`
  - `generate_appcast` reads EdDSA key from macOS Keychain

## Testing

- Test target: `BaudKitTests` at `Tests/BaudKitTests/`
- Uses Swift Testing framework (`import Testing`, `@Suite`, `@Test`, `#expect`)
- Focus on pure functions/structs: Models, SLCANResponse.parse, SLCANCommand.commandString, HexFormatter, DBCParser, ProtocolDecoder
- `@MainActor` / `@Observable` service classes (SerialDataManager, CANSignalStore, etc.) are not unit-tested

## Layout Conventions

- **Golden ratio** (0.618 : 0.382) for left/right column `idealWidth` via `GeometryReader`
- `HSplitView` with `idealWidth` set per pane — user can still drag to resize
- Main view toolbars use `.toolbar` for Liquid Glass integration; Sheet actions use `ToolbarItem(placement:)`
- Content-layer controls (chart headers, send bars, stability gauges) remain inline HStack

## SwiftUI Patterns & Pitfalls

- `@Environment(Type.self)` for DI, **not** `@EnvironmentObject`
- `@Bindable var x = x` inside `body` when you need `$` bindings from `@Observable` env objects
- Toolbar buttons must use `Label("text", systemImage:)` — no bare `Image`, no `.symbolVariant()`, no `Menu` wrapper, no `HStack` wrapper (causes hover overflow)
- Use `.toolbar { ToolbarItemGroup(placement: .primaryAction) }` for main view toolbars (Liquid Glass auto-applies)
- Use `ToolbarItem(placement: .cancellationAction)` / `.confirmationAction` for Sheet action buttons
- Use `.buttonStyle(.glassProminent)` for primary actions, `.glass` for secondary (replaces `.borderedProminent` / `.bordered`)
- `@Bindable var x = x` must be at body's top level (before `GeometryReader`) for `.toolbar` to access `$x` bindings
- Auto scroll: use `onScrollPhaseChange` detecting `.interacting` phase on macOS (not `ScrollViewReader` + timer hacks)
- Table auto scroll: `ScrollPosition` + `scrollTo(edge:)` doesn't work on Table. Use `NSScrollView` access via `NSViewRepresentable` helper to call `scrollToBottom()` directly
- `.searchable` can be placed on child views inside a parent layout — it propagates up
- `Table(of:)` with `ForEach` + `TableRow` for complex row content, not `Table(data) { param in ... }`

## Localization

- Two locales: `en` + `zh-Hans` via `.lproj/Localizable.strings`
- Files at `BaudKit/Resources/en.lproj/` and `BaudKit/Resources/zh-Hans.lproj/`
- App target has file copies at `Baud/App/Resources/`
- `Package.swift` has `defaultLocalization: "en"` and `resources: [.process("Resources")]`

## Key Architecture Decisions

### Connection Page Layout
```
[ConnectionHeroAnimation — wave path animation responding to config changes]
[Form: Port | Serial Configuration | Connect/Disconnect]
```

### Serial Terminal Layout
```
Left Column (0.618):
  [Console (full width, QuickSend slides in from right when toggled)]
  [DisplayMode picker | QuickSend | Export | Clear | Protocol | Protocol Config | Mock]
  [ProtocolFramesView (collapsible, 160pt when expanded)]
  [SendBar]
Right Column (0.382):
  [SerialChartView (DGCharts)]
```

### SLCAN Debugger Layout
```
Left Column (0.618):
  [Trace/Monitor picker | Open/Close CAN | Send | Settings | Import DBC | Export | Clear | Mock]
  [CANFrameListView or CANMonitorView]
  [CANFrameDetailView (180pt, when frame selected, shows decoded signal values)]
Right Column (0.382):
  [CANChartView (DGCharts) with signal charts]
```

### CAN Frame Detail — Signal Decoding
- `CANFrameDetailView` reads `CANSignalStore` via `@Environment`
- Filters signals by `arbitrationID == frame.arbitrationID && enabled`
- Calls `signal.extractValue(from: frame.data)` for each match
- Shows signal name + physical value below frame info, hidden when no matches

### CAN Signal System
- `CANSignal` model: start bit, bit length, big/little endian, signed/unsigned, factor/offset
- `CANSignalStore`: manages signals + chart data, persists to `UserDefaults`
- Signal tags in CANChartView: delete button (×) placed before signal name for stable click position

### DBC File Import
- `DBCParser`: parses standard .dbc format (BO_ and SG_ entries only)
- `DBCImportView`: NSOpenPanel → parse → message preview with selection → import to CANSignalStore
- User must select messages before importing (none pre-selected)
- DBC byte order: `@0` = Motorola (big endian), `@1` = Intel (little endian)

### Data Export
- `DataExporter`: supports text, CSV, JSON for serial messages, CAN frames, and recorded sessions
- Format picker (NSAlert) → NSSavePanel, file extension matches format
- Export buttons disabled when no data

### Protocol Decoder
- `ProtocolDefinition` model: header bytes, length field (0/1/2 bytes), fixed length mode, checksum (XOR/Sum/CRC-8/CRC-16)
- `ProtocolDecoder`: stateful byte stream parser, accumulates buffer, searches headers, extracts frames
- `ProtocolConfigView`: CRUD for protocol definitions, persisted to UserDefaults
- `ProtocolFramesView`: collapsible panel in SerialTerminalView showing decoded frames
- `SerialDataManager` integrates decoder when `activeProtocol` is set

### Session Recording
- `SessionManager` stores sessions as individual JSON files in `~/Library/Application Support/Baud/Sessions/`
- Auto-migrates from UserDefaults on first launch
- Sessions exportable via right-click → Export with format picker

### Chart Data Clearing
- Both Serial and CAN charts detect data gaps (>0.5s silence → new data = clear chart)

### Persistence (UserDefaults)
- Serial config, selected port, display mode, hex mode, line ending
- Auto send interval, CAN signals, quick send snippets, protocol definitions
- Recorded sessions now in files, not UserDefaults

## Notification Names

- `Notification.Name.serialDataReceived` — posted by `SerialDataManager.appendReceived`
- `Notification.Name.slcanFrameReceived` — used by frame store + signal store + monitor view
- `Notification.Name.clearConsole` — external clear trigger

## CI/CD

- Release workflow: tag `v*` → build DMG → sign with EdDSA → generate appcast.xml → commit to Docs/ → GitHub Release
- `generate_appcast` reads Sparkle version from `Package.resolved` (Python one-liner, no multi-line YAML)
- `appcast.xml` served via `raw.githubusercontent.com`, not GitHub Pages
