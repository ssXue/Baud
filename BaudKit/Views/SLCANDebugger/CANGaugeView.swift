import SwiftUI

struct CANGaugeView: View {
    @Environment(CANSignalStore.self) private var signalStore

    private var enabledSignals: [CANSignal] {
        signalStore.signals.filter { $0.enabled }
    }

    var body: some View {
        let _ = signalStore.chartRevision

        if enabledSignals.isEmpty {
            Text("No signals")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let columns = [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ]
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(enabledSignals) { signal in
                    GaugeCard(signal: signal, value: currentValue(for: signal))
                }
            }
            .padding(8)
        }
    }

    private func currentValue(for signal: CANSignal) -> Double? {
        guard let data = signalStore.chartData[signal.id], let last = data.last else {
            return nil
        }
        return last.value
    }
}

private struct GaugeCard: View {
    let signal: CANSignal
    let value: Double?

    var body: some View {
        VStack(spacing: 2) {
            GaugeArcView(
                value: value ?? signal.minDisplay,
                minValue: signal.minDisplay,
                maxValue: signal.maxDisplay
            )
            .frame(width: 150, height: 90)

            Text(formattedValue)
                .font(.system(.title2, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(signal.name)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 150, height: 120)
    }

    private var formattedValue: String {
        guard let v = value else { return "--" }
        if abs(v) >= 1000 {
            return String(format: "%.0f", v)
        } else if abs(v) >= 100 {
            return String(format: "%.1f", v)
        } else {
            return String(format: "%.2f", v)
        }
    }
}

private struct GaugeArcBackground: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: rect.width / 2,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        return path.strokedPath(StrokeStyle(lineWidth: 14, lineCap: .round))
    }
}

private struct GaugeArcForeground: Shape {
    let fraction: Double

    func path(in rect: CGRect) -> Path {
        let endAngle = Angle.degrees(180 - fraction * 180)
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: rect.width / 2,
            startAngle: .degrees(180),
            endAngle: endAngle,
            clockwise: false
        )
        return path.strokedPath(StrokeStyle(lineWidth: 14, lineCap: .round))
    }
}

private struct GaugeArcView: View {
    let value: Double
    let minValue: Double
    let maxValue: Double

    private var fraction: Double {
        let range = maxValue - minValue
        guard range > 0 else { return 0 }
        return max(0, min(1, (value - minValue) / range))
    }

    var body: some View {
        ZStack {
            GaugeArcBackground()
                .foregroundStyle(.quaternary)

            GaugeArcForeground(fraction: fraction)
                .foregroundStyle(colorForFraction(fraction))

            HStack {
                Text(formatTick(minValue))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTick(maxValue))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .offset(y: -4)
        }
    }

    private func formatTick(_ v: Double) -> String {
        if abs(v) >= 1000 { return String(format: "%.0f", v) }
        if abs(v) >= 100 { return String(format: "%.0f", v) }
        if abs(v) >= 1 { return String(format: "%.1f", v) }
        return String(format: "%.2f", v)
    }

    private func colorForFraction(_ f: Double) -> Color {
        switch f {
        case ..<0.5: .green
        case 0.5..<0.8: .orange
        default: .red
        }
    }
}

#Preview {
    CANGaugeView()
        .environment(CANSignalStore())
}
