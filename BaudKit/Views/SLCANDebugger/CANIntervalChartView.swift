import SwiftUI
import DGCharts

public struct CANIntervalChartView: View {
    @Environment(CANBusAnalyzer.self) private var analyzer

    private let channelColors: [NSColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemPink, .systemRed, .systemCyan, .systemYellow, .systemMint, .systemIndigo]

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(Array(analyzer.statsList.enumerated()), id: \.element.arbitrationID) { index, stats in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(channelColors[index % channelColors.count]))
                                .frame(width: 6, height: 6)
                            Text(stats.idHex)
                                .font(.system(.caption2, design: .monospaced))
                            if let jitter = stats.jitter {
                                Text(String(format: "%.1fms", jitter * 1000))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                Button("Clear") {
                    analyzer.clearIntervals()
                }
                .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 4)

            if analyzer.idStats.isEmpty {
                Text("No data yet. Open CAN bus to start analysis.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                IntervalLineChartRepresentable(
                    statsList: analyzer.statsList,
                    colors: channelColors
                )
                .padding(8)
            }
        }
        .frame(minWidth: 250)
    }
}

private struct IntervalLineChartRepresentable: NSViewRepresentable {
    let statsList: [CANIDStats]
    let colors: [NSColor]

    func makeNSView(context: Context) -> LineChartView {
        let chart = LineChartView()
        chart.rightAxis.enabled = true
        chart.leftAxis.enabled = false
        chart.xAxis.granularity = 1
        chart.xAxis.labelPosition = .bottom
        chart.xAxis.valueFormatter = IndexAxisValueFormatter()
        chart.legend.enabled = true
        chart.legend.form = .circle
        chart.legend.font = .systemFont(ofSize: 10)
        chart.doubleTapToZoomEnabled = true
        chart.pinchZoomEnabled = true
        chart.dragEnabled = true
        chart.autoScaleMinMaxEnabled = true
        chart.rightAxis.valueFormatter = IntervalValueFormatter()
        chart.rightAxis.granularity = 0.001
        return chart
    }

    func updateNSView(_ chart: LineChartView, context: Context) {
        var dataSets: [LineChartDataSet] = []

        for (index, stats) in statsList.enumerated() {
            guard !stats.intervals.isEmpty else { continue }
            let entries = stats.intervals.enumerated().map { i, interval in
                ChartDataEntry(x: Double(i), y: interval * 1000) // Convert to ms
            }

            let dataSet = LineChartDataSet(entries: entries, label: stats.idHex)
            dataSet.colors = [colors[index % colors.count]]
            dataSet.drawCirclesEnabled = false
            dataSet.drawValuesEnabled = false
            dataSet.lineWidth = 1.5
            dataSet.mode = .linear

            dataSets.append(dataSet)
        }

        chart.data = LineChartData(dataSets: dataSets)
        chart.rightAxis.axisMinimum = 0
        chart.notifyDataSetChanged()
        chart.setNeedsDisplay(chart.bounds)
    }
}

private class IntervalValueFormatter: NSObject, AxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        String(format: "%.1fms", value)
    }
}
