# AGENTS.md

This file summarizes key decisions, conventions, and pitfalls discovered during development.

## Build & Run

```bash
swift build                      # SPM build
swift build 2>&1 | grep error    # Check errors only
./build-app.sh --run             # Wrap into .app bundle and launch (required for localization)
```

- `build-app.sh` creates `.build/arm64-apple-macosx/debug/Baud.app` — SPM bare executable can't find `Bundle.main` resources
- Must re-run `build-app.sh` after any build to pick up resource changes

## Dependencies

- **ORSSerialPort** (2.1.0) — IOKit USB CDC serial port discovery and I/O
- **DGCharts** (5.1.0) — ChartsOrg/Charts, real-time line charts via `NSViewRepresentable`
  - Import as `import DGCharts` (renamed from Charts to avoid conflict with Apple Swift Charts)
  - Use `LineChartView` wrapped in `NSViewRepresentable`
  - Must call `chart.notifyDataSetChanged()` + `chart.setNeedsDisplay()` after data updates
  - X-axis formatter: `ChartXAxisFormatter` in `Views/ChartXAxisFormatter.swift`

## Layout Conventions

- **Golden ratio** (0.618 : 0.382) for left/right column `idealWidth` via `GeometryReader`
- `HSplitView` with `idealWidth` set per pane — user can still drag to resize
- Buttons belong **inline** in the view (HStack rows), not in window-level `.toolbar` — toolbar renders at far right of window and doesn't align with content columns

## SwiftUI Patterns & Pitfalls

- `@Environment(Type.self)` for DI, **not** `@EnvironmentObject`
- `@Bindable var x = x` inside `body` when you need `$` bindings from `@Observable` env objects
- Toolbar buttons must use `Label("text", systemImage:)` — no bare `Image`, no `.symbolVariant()`, no `Menu` wrapper, no `HStack` wrapper (causes hover overflow)
- Auto scroll: use `onScrollPhaseChange` detecting `.interacting` phase on macOS (not `ScrollViewReader` + timer hacks)
- Table auto scroll: `ScrollPosition` + `scrollTo(edge:)` doesn't work on Table. Use `NSScrollView` access via `NSViewRepresentable` helper to call `scrollToBottom()` directly
- `.searchable` can be placed on child views inside a parent layout — it propagates up

## Localization

- Two locales: `en` + `zh-Hans` via `.lproj/Localizable.strings`
- Files at `BaudKit/Resources/en.lproj/` and `BaudKit/Resources/zh-Hans.lproj/`
- App target has symlinked copies at `Baud/App/Resources/`
- `Package.swift` has `defaultLocalization: "en"` and `resources: [.process("Resources")]`

## Key Architecture Decisions

### Connection Page Layout
```
[ConnectionHeroAnimation — wave path animation responding to config changes]
[Form: Port | Serial Configuration | Connect/Disconnect]
```
- Hero animation: `Canvas` + timer at 25ms, wave parameters respond to baud rate (speed/count), data bits (amplitude), parity (ripple), stop bits (perturbation)
- Baud rate range: 9600–921600 (sub-9600 removed)
- Four-edge gradient overlays for smooth fade-to-background

### Serial Terminal Layout
```
Left Column (0.618):
  [Console (full width, QuickSend slides in from right when toggled)]
  [DisplayMode picker | QuickSend | Clear | Mock]
  [SendBar]
Right Column (0.382):
  [SerialChartView (DGCharts)]
```

### SLCAN Debugger Layout
```
Left Column (0.618):
  [Trace/Monitor picker | Open/Close CAN | Send | Filter | Clear | Mock]
  [CANFrameListView or CANMonitorView]
  [CANFrameDetailView (180pt, when frame selected)]
Right Column (0.382):
  [CANChartView (DGCharts) with signal charts]
```

### Recorder Layout
```
Left Column (0.618):
  [Record/Stop button | event count]
  [SessionTimelineView — Table with time/direction/data]
Right Column (0.382):
  [Sessions list | playback controls (Play/Slider/progress)]
```

### CAN View Modes
- **Trace**: chronological scroll, ring buffer 10K frames, for packet capture
- **Monitor**: `[UInt32: CANFrame]` dictionary keyed by arbitration ID, same ID updates in-place with latest data + timestamp, for node status monitoring

### QuickSend Panel
- Toggle via inline button, **not** always visible
- Slides in as right-side panel inside Console HStack, Console shrinks to accommodate
- Has inline close (×) button

### CAN Signal System
- `CANSignal` model: start bit, bit length, big/little endian, signed/unsigned, factor/offset
- `CANSignalStore`: manages signals + chart data, persists to `UserDefaults`
- Bit extraction supports both Motorola (big endian) and Intel (little endian) byte ordering

### Chart Data Clearing
- Both Serial and CAN charts detect data gaps (>0.5s silence → new data = clear chart)
- This ensures each "session" of continuous data gets a clean chart

### Persistence (UserDefaults)
- Serial config (`SerialPortConfig` Codable), selected port, display mode, hex mode, line ending
- Auto send interval, CAN signals, quick send snippets
- Recorded sessions (JSON encoded)

## Notification Names

- `Notification.Name.serialDataReceived` — posted by `SerialDataManager.appendReceived`, used by chart + recorder
- `Notification.Name.slcanFrameReceived` — used by frame store + signal store + monitor view
- `Notification.Name.clearConsole` — external clear trigger

## Mock Data

### Serial Mock
- Three-channel sine waves: `sin(t*2)*100, cos(t*0.7)*50+25, sin(t*1.3+1)*30+60`
- Updates every 100ms via Timer
- Posts via `serialDataReceived` notification

### CAN Mock
- Generates on CAN ID 0x0C4:
  - RPM: byte 0-1 little endian
  - Speed: byte 2-3 little endian
  - Temp: byte 4
- Updates every 50ms via Timer
