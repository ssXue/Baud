import SwiftUI
import DGCharts

public struct CANBusLoadChartView: View {
    @Environment(CANFrameStore.self) private var frameStore
    @Environment(CANBusAnalyzer.self) private var analyzer

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Frame Distribution")
                    .font(.system(.caption, weight: .semibold))
                Spacer()
                Text("\(analyzer.statsList.count) IDs")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 4)

            if analyzer.statsList.isEmpty {
                Text("No frames received yet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CANFrameBarChartRepresentable(stats: analyzer.statsList, revision: analyzer.statsRevision)
                    .padding(8)
            }
        }
        .frame(minHeight: 150)
    }
}

private struct CANFrameBarChartRepresentable: NSViewRepresentable {
    let stats: [CANIDStats]
    let revision: Int

    private let barColors: [NSColor] = [.systemBlue, .systemTeal, .systemOrange, .systemPurple, .systemPink, .systemGreen, .systemYellow, .systemIndigo]

    func makeNSView(context: Context) -> BarChartView {
        let chart = BarChartView()
        chart.rightAxis.enabled = false
        chart.leftAxis.labelFont = .systemFont(ofSize: 10)
        chart.xAxis.labelFont = .monospacedSystemFont(ofSize: 9, weight: .regular)
        chart.xAxis.labelRotationAngle = -45
        chart.xAxis.granularity = 1
        chart.legend.enabled = false
        chart.doubleTapToZoomEnabled = false
        chart.pinchZoomEnabled = false
        chart.dragEnabled = true
        chart.autoScaleMinMaxEnabled = true
        chart.drawBarShadowEnabled = false
        chart.drawValueAboveBarEnabled = true
        return chart
    }

    func updateNSView(_ chart: BarChartView, context: Context) {
        let sorted = stats.sorted { $0.frameCount > $1.frameCount }
        let entries = sorted.enumerated().map { index, stat in
            BarChartDataEntry(x: Double(index), y: Double(stat.frameCount))
        }

        let dataSet = BarChartDataSet(entries: entries)
        dataSet.colors = sorted.enumerated().map { index, _ in barColors[index % barColors.count] }
        dataSet.valueFormatter = BarValueFormatter()
        dataSet.valueFont = .systemFont(ofSize: 9)

        chart.data = BarChartData(dataSet: dataSet)
        chart.xAxis.valueFormatter = IDAxisFormatter(ids: sorted.map { $0.idHex })

        chart.notifyDataSetChanged()
        chart.setNeedsDisplay(chart.bounds)
    }
}

private class IDAxisFormatter: NSObject, AxisValueFormatter {
    let ids: [String]
    init(ids: [String]) { self.ids = ids }
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let index = Int(value)
        guard index >= 0, index < ids.count else { return "" }
        return ids[index]
    }
}

private class BarValueFormatter: NSObject, ValueFormatter {
    func stringForValue(_ value: Double, entry: DGCharts.ChartDataEntry, dataSetIndex: Int, viewPortHandler: DGCharts.ViewPortHandler?) -> String {
        value >= 1000 ? String(format: "%.1fk", value / 1000) : String(format: "%.0f", value)
    }
}
