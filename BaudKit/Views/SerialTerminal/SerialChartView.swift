import SwiftUI
import DGCharts

public struct SerialChartView: View {
    @Environment(SerialDataManager.self) private var dataManager
    @State private var channels: [SerialChartChannel] = []
    @State private var maxPoints = 200
    @State private var lastDataTime: Date = .distantPast

    private let channelColors: [NSColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemPink, .systemRed, .systemCyan, .systemYellow]

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Chart")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $maxPoints) {
                    Text("100").tag(100)
                    Text("200").tag(200)
                    Text("500").tag(500)
                }
                .frame(width: 80)
                .labelsHidden()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if channels.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 28))
                        .foregroundStyle(.quaternary)
                    Text("Waiting for numeric data...")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("Send comma/space separated numbers per line")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                SerialLineChartRepresentable(channels: channels, maxPoints: maxPoints)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }

            Divider()

            HStack(spacing: 8) {
                Spacer()
                Button("Clear") {
                    channels.removeAll()
                }
                .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(minWidth: 250)
        .onReceive(NotificationCenter.default.publisher(for: .serialDataReceived)) { notification in
            guard let text = notification.userInfo?["text"] as? String else { return }
            parseAndAppend(text)
        }
    }

    private func parseAndAppend(_ text: String) {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return }

        let now = Date()
        if now.timeIntervalSince(lastDataTime) > 0.5 {
            channels.removeAll()
        }
        lastDataTime = now

        let separators = CharacterSet(charactersIn: ", \t;")
        let tokens = line.components(separatedBy: separators).filter { !$0.isEmpty }
        let values = tokens.compactMap { Double($0) }
        guard !values.isEmpty else { return }

        for (i, value) in values.enumerated() {
            if i < channels.count {
                channels[i].points.append(ChartPoint(timestamp: Date(), value: value))
                if channels[i].points.count > maxPoints * 2 {
                    channels[i].points.removeFirst(channels[i].points.count - maxPoints)
                }
            } else {
                let name = values.count == 1 ? "Value" : "Ch\(i + 1)"
                let color = channelColors[i % channelColors.count]
                channels.append(SerialChartChannel(name: name, color: color, points: [ChartPoint(timestamp: Date(), value: value)]))
            }
        }
    }
}

private struct SerialChartChannel: Identifiable {
    let id = UUID()
    let name: String
    let color: NSColor
    var points: [ChartPoint]
}

private struct ChartPoint {
    let timestamp: Date
    let value: Double
}

private struct SerialLineChartRepresentable: NSViewRepresentable {
    let channels: [SerialChartChannel]
    let maxPoints: Int

    func makeNSView(context: Context) -> LineChartView {
        let chart = LineChartView()
        chart.rightAxis.enabled = true
        chart.leftAxis.enabled = false
        chart.xAxis.granularity = 1
        chart.xAxis.labelPosition = .bottom
        chart.legend.enabled = true
        chart.legend.form = .circle
        chart.legend.font = .systemFont(ofSize: 10)
        chart.doubleTapToZoomEnabled = true
        chart.pinchZoomEnabled = true
        chart.dragEnabled = true
        chart.autoScaleMinMaxEnabled = true
        return chart
    }

    func updateNSView(_ chart: LineChartView, context: Context) {
        var dataSets: [LineChartDataSet] = []

        for channel in channels {
            let points = Array(channel.points.suffix(maxPoints))
            let entries = points.map { point in
                ChartDataEntry(x: point.timestamp.timeIntervalSince1970, y: point.value)
            }

            let dataSet = LineChartDataSet(entries: entries, label: channel.name)
            dataSet.colors = [channel.color]
            dataSet.drawCirclesEnabled = false
            dataSet.drawValuesEnabled = false
            dataSet.lineWidth = 1.5
            dataSet.mode = .linear

            dataSets.append(dataSet)
        }

        chart.data = LineChartData(dataSets: dataSets)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        chart.xAxis.valueFormatter = ChartXAxisFormatter(dateFormatter: dateFormatter)
        chart.notifyDataSetChanged()
        chart.setNeedsDisplay(chart.bounds)
    }
}

public extension Notification.Name {
    static let serialDataReceived = Notification.Name("serialDataReceived")
}
