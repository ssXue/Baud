import SwiftUI
import DGCharts

public struct CANChartView: View {
    @Environment(CANSignalStore.self) private var signalStore
    @State private var showAddSheet = false

    private let channelColors: [NSColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemPink, .systemRed, .systemCyan, .systemYellow, .systemMint, .systemIndigo]

    public init() {}

    public var body: some View {
        @Bindable var signalStore = signalStore
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(signalStore.signals) { signal in
                        let colorIndex = signalStore.signals.firstIndex(where: { $0.id == signal.id }) ?? 0
                        HStack(spacing: 4) {
                            Button {
                                signalStore.removeSignal(id: signal.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(.caption2))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            Circle()
                                .fill(Color(channelColors[colorIndex % channelColors.count]))
                                .frame(width: 6, height: 6)
                            Text(signal.name)
                                .font(.system(.caption2))
                                .lineLimit(1)
                            if let points = signalStore.chartData[signal.id], let last = points.last {
                                Text(String(format: "%.2f", last.value))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                Picker("", selection: $signalStore.maxPoints) {
                    Text("100").tag(100)
                    Text("200").tag(200)
                    Text("500").tag(500)
                }
                .frame(width: 80)
                .labelsHidden()

                Button("Clear") {
                    signalStore.clearChartData()
                }
                .font(.caption)

                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 4)

            if signalStore.signals.isEmpty {
                Text("No signals configured. Tap + to add.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CANLineChartRepresentable(
                    signals: signalStore.signals,
                    chartData: signalStore.chartData,
                    maxPoints: signalStore.maxPoints,
                    colors: channelColors,
                    revision: signalStore.chartRevision
                )
                .padding(8)
            }
        }
        .frame(minWidth: 250)
        .sheet(isPresented: $showAddSheet) {
            CANSignalConfigView()
        }
    }
}

private struct CANLineChartRepresentable: NSViewRepresentable {
    let signals: [CANSignal]
    let chartData: [UUID: [SignalDataPoint]]
    let maxPoints: Int
    let colors: [NSColor]
    let revision: Int

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

        for (index, signal) in signals.enumerated() {
            guard let points = chartData[signal.id] else { continue }
            let sliced = Array(points.suffix(maxPoints))
            let entries = sliced.map { point in
                ChartDataEntry(x: point.timestamp.timeIntervalSince1970, y: point.value)
            }

            let dataSet = LineChartDataSet(entries: entries, label: signal.name)
            dataSet.colors = [colors[index % colors.count]]
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
