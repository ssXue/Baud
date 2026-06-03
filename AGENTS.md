# AGENTS.md

This file summarizes key decisions, conventions, and pitfalls discovered during development.

## Build & Run

```bash
swift build                      # SPM build
swift test                       # Run unit tests (93 tests, 11 suites)
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
  [Console (.searchable搜索+高亮, QuickSend slides in from right when toggled)]
  [DisplayMode picker | QuickSend | Export | Clear | Protocol | Protocol Config | Mock]
  [ProtocolFramesView (collapsible, 160pt when expanded)]
  [SerialStatsBar (RX/TX字节计数+速率)]
  [SendBar]
Right Column (0.382):
  [SerialChartView (DGCharts)]
```

### SLCAN Debugger Layout
```
Left Column (0.618):
  [Trace/Monitor/Stability picker | Open/Close CAN | Send | Settings | Import DBC | Export | Clear | Mock]
  [CANFrameListView or CANMonitorView or CANStabilityView]
  [CANFrameDetailView (180pt, when frame selected, shows decoded signal values with Value Table)]
Right Column (0.382):
  Trace/Monitor mode:
    [CANChartView (DGCharts) with signal charts]
    [CANGaugeView (scrollable, max 200pt, semi-circular gauges)]
  Stability mode:
    [CANIntervalChartView]
```

### CAN Frame Detail — Signal Decoding
- `CANFrameDetailView` reads `CANSignalStore` via `@Environment`
- Filters signals by `arbitrationID == frame.arbitrationID && enabled`
- Calls `signal.extractValue(from: frame.data)` for each match
- Shows signal name + physical value below frame info, hidden when no matches

### CAN Value Table
- `CANSignal.valueTable: [Int: String]` maps raw integer values to display labels
- `displayValue(raw:)` returns "Label (N)" when mapped, formatted number otherwise
- Shown in CANFrameDetailView, CANMonitorView, and CANSignalConfigView

### CAN Gauge View
- `CANGaugeView`: pure SwiftUI semi-circular arc gauge for real-time signal values
- LazyVGrid two-column layout, 150x120 cards
- Displayed in right sidebar below CANChartView (non-stability mode only)

### CAN Error Frame Analysis
- Stability mode shows error summary bar + expandable detail table
- Data from `CANBusAnalyzer.errorEvents`, aggregated by error code
- Error stats: code, description, count, last seen

### CAN Send Panel (TSmaster-style)
- `CANTxMessage` model: arbitration ID, data, period, enabled, optional signal generator
- `SignalGenerator`: waveform (sine/square/triangle/sawtooth), amplitude, offset, frequency; applies to target byte
- `CANTxStore`: manages message list + periodic timers, persists to `UserDefaults`
- `CANSendView`: table-based send panel (not one-shot), edit via sheet, per-row enable/send/edit/delete
- TSmaster-style: multiple messages with independent periods, waveform generators, send-all

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
### Session Recording & Playback
- `SessionManager` stores sessions as individual JSON files in `~/Library/Application Support/Baud/Sessions/`
- Auto-migrates from UserDefaults on first launch
- Sessions exportable via right-click → Export with format picker
- Playback speed control: 0.25x / 0.5x / 1x / 2x / 4x, instant speed change via time re-baselining
- 串口+CAN联动录制: SessionRecorder 同时监听 .serialDataReceived 和 .slcanFrameReceived
- 数据比对: DataDiffView 并排比较两个 session 的消息差异（match/mismatch/leftOnly/rightOnly）
- QuickSend snippets 支持拖拽排序 (.onMove)

### Serial Data Visualization
- HEX/HEX+ASCII modes use per-byte coloring in SerialConsoleView
- Color scheme: NUL=gray, LF/CR/TAB=blue, control chars=orange, DEL=red, high bytes=purple, printable=default
- Control characters display as names (NUL, LF, CR, TAB, C-A..C-_, DEL)
- Max 32 bytes per row to prevent layout issues

### Keyboard Shortcuts
- ⌘1/2/3/4 切换 Connection/Terminal/SLCAN/Recorder 页面
- ⌘K 清除 Console
- ⌘F 聚焦搜索
- 导航通知: .navigateToConnection / .navigateToTerminal / .navigateToSLCAN / .navigateToRecorder

### Search Highlight
- `HighlightUtils.highlightedText()` case-insensitive 高亮匹配文本
- 串口终端: .searchable + 高亮
- CAN 帧列表: filterText 高亮（保留过滤逻辑）

### Window State
- selectedPage 持久化到 UserDefaults, 启动时恢复
- HSplitView 分割比例 / 窗口尺寸由 macOS 自动恢复

### Project Import/Export
- `BaudProject` model captures all UserDefaults config keys (serial, CAN, protocol, snippets)
- `ProjectManager`: export to .baud JSON file, import restores all keys + posts `.projectImported`
- CANSignalStore and CANTxStore auto-reload on `.projectImported` notification
- File menu: Save Project... (⇧⌘S) / Open Project... (⇧⌘O)

### Chart Data Clearing
- Both Serial and CAN charts detect data gaps (>0.5s silence → new data = clear chart)

### Persistence (UserDefaults)
- Serial config, selected port, display mode, hex mode, line ending
- Auto send interval, CAN signals, CAN TX messages, quick send snippets, protocol definitions
- Recorded sessions now in files, not UserDefaults

## Notification Names

- `Notification.Name.serialDataReceived` — posted by `SerialDataManager.appendReceived`
- `Notification.Name.slcanFrameReceived` — used by frame store + signal store + monitor view + session recorder
- `Notification.Name.clearConsole` — external clear trigger
- `Notification.Name.projectImported` — triggers CANSignalStore + CANTxStore reload
- `Notification.Name.navigateToConnection/Terminal/SLCAN/Recorder` — keyboard shortcut page switching
- All notification names centralized in `BaudKit/Utils/NotificationNames.swift`

## CI/CD

- Release workflow: tag `v*` → build DMG → sign with EdDSA → generate appcast.xml → commit to Docs/ → GitHub Release
- `generate_appcast` reads Sparkle version from `Package.resolved` (Python one-liner, no multi-line YAML)
- `appcast.xml` served via `raw.githubusercontent.com`, not GitHub Pages
