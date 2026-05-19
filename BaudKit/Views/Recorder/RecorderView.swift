import SwiftUI

public struct RecorderView: View {
    @Environment(SerialPortManager.self) private var portManager
    @Environment(SessionRecorder.self) private var recorder
    @Environment(SessionManager.self) private var sessionManager

    @State private var isPlaying = false
    @State private var playbackProgress: Double = 0
    @State private var playbackTimer: Timer?
    @State private var playbackEventIDs: Set<UUID> = []
    @State private var playbackStartReal: Date = .distantPast
    @State private var playbackStartOffset: Int64 = 0

    public init() {}

    public var body: some View {
        @Bindable var recorder = recorder
        @Bindable var sessionManager = sessionManager
        GeometryReader { geo in
            HSplitView {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        if recorder.isRecording {
                            Button {
                                if let session = recorder.stopRecording() {
                                    sessionManager.addSession(session)
                                }
                            } label: {
                                Label("Stop", systemImage: "stop.circle.fill")
                            }
                            .foregroundStyle(.red)
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                            Text("Recording... \(recorder.recordedEvents.count) events")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Button {
                                recorder.startRecording()
                            } label: {
                                Label("Record", systemImage: "record.circle")
                            }
                            .disabled(!portManager.isConnected)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    Divider()

                    if let session = sessionManager.selectedSession {
                        SessionTimelineView(events: visibleEvents(for: session))
                    } else {
                        Text("Select a session to inspect")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(idealWidth: geo.size.width * 0.618)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Sessions")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    List(selection: $sessionManager.selectedSessionID) {
                        ForEach(sessionManager.sessions) { session in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.name)
                                    .font(.system(.body))
                                HStack(spacing: 8) {
                                    Text("\(session.eventCount) events")
                                    Text("·")
                                    Text(formatDuration(session.durationMs))
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .tag(session.id)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    sessionManager.deleteSession(id: session.id)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)

                    Divider()

                    if let session = sessionManager.selectedSession {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Button {
                                    togglePlayback(session: session)
                                } label: {
                                    Label(isPlaying ? "Stop" : "Play", systemImage: isPlaying ? "stop.circle" : "play.circle")
                                }
                                .font(.caption)

                                if session.durationMs > 0 {
                                    Slider(value: $playbackProgress, in: 0...1)
                                        .font(.caption)
                                }

                                Text(formatDuration(Int64(Double(session.durationMs) * playbackProgress)))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60)
                            }
                        }
                        .padding(12)
                    }
                }
                .frame(idealWidth: geo.size.width * 0.382)
            }
        }
        .navigationTitle("Recorder")
    }

    private func visibleEvents(for session: RecordedSession) -> [RecordedEvent] {
        if isPlaying {
            let currentOffset = Int64(Double(session.durationMs) * playbackProgress)
            return session.events.filter { $0.offsetMs <= currentOffset }
        }
        return session.events
    }

    private func togglePlayback(session: RecordedSession) {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback(session: session)
        }
    }

    private func startPlayback(session: RecordedSession) {
        isPlaying = true
        playbackProgress = 0
        playbackStartReal = Date()
        let duration = session.durationMs

        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            Task { @MainActor in
                let elapsed = Date().timeIntervalSince(playbackStartReal) * 1000
                if duration > 0 {
                    playbackProgress = min(1.0, elapsed / Double(duration))
                }
                if elapsed >= Double(duration) {
                    playbackProgress = 1.0
                    stopPlayback()
                }

                let currentOffset = Int64(elapsed)
                let pending = session.events.filter { event in
                    event.offsetMs <= currentOffset && !playbackEventIDs.contains(event.id)
                }
                for event in pending {
                    playbackEventIDs.insert(event.id)
                    if event.direction == .received {
                        NotificationCenter.default.post(name: .serialDataReceived, object: nil, userInfo: ["text": String(data: event.data, encoding: .utf8) ?? ""])
                    }
                }
            }
        }
    }

    private func stopPlayback() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        playbackEventIDs.removeAll()
    }

    private func formatDuration(_ ms: Int64) -> String {
        let s = Double(ms) / 1000.0
        return String(format: "%.1fs", s)
    }
}

private struct SessionTimelineView: View {
    let events: [RecordedEvent]

    var body: some View {
        Table(events) {
            TableColumn("Time") { event in
                Text(String(format: "%.3fs", Double(event.offsetMs) / 1000.0))
                    .font(.system(.caption, design: .monospaced))
            }
            .width(min: 70, ideal: 80)

            TableColumn("Dir") { event in
                Text(event.direction == .sent ? "TX" : "RX")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(event.direction == .sent ? .blue : .green)
            }
            .width(min: 36, ideal: 40)

            TableColumn("Data") { event in
                if let text = String(data: event.data, encoding: .utf8) {
                    Text(text.trimmingCharacters(in: .controlCharacters))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                } else {
                    Text(event.data.map { String(format: "%02X", $0) }.joined(separator: " "))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .tableStyle(.automatic)
    }
}
