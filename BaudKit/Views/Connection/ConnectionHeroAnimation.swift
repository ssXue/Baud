import SwiftUI

struct ConnectionHeroAnimation: View {
    let config: SerialPortConfig
    let isConnected: Bool

    @State private var phase: CGFloat = 0
    @State private var pulsePhase: CGFloat = 0
    @State private var sparks: [Spark] = []

    private let timer = Timer.publish(every: 0.025, on: .main, in: .common).autoconnect()
    private let sparkTimer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { context, size in
            let baseColor: Color = isConnected ? .green : .accentColor
            let waveAmplitude: CGFloat = 16 * amplitudeScale
            let waveLength: CGFloat = size.width / CGFloat(waveCountForBaudRate)
            let yCenter = size.height / 2

            drawGrid(context: context, size: size, color: baseColor)

            drawFlowingWave(context: context, size: size, yBase: yCenter, amplitude: waveAmplitude * 2.5, waveLength: waveLength * 1.5, color: baseColor.opacity(0.04), lineWidth: 1.5, phaseOffset: 0.7)
            drawFlowingWave(context: context, size: size, yBase: yCenter, amplitude: waveAmplitude * 1.8, waveLength: waveLength * 1.2, color: baseColor.opacity(0.07), lineWidth: 1.5, phaseOffset: 0.4)
            drawFlowingWave(context: context, size: size, yBase: yCenter, amplitude: waveAmplitude * 1.3, waveLength: waveLength * 0.9, color: baseColor.opacity(0.12), lineWidth: 2, phaseOffset: 0.15)

            drawMainWave(context: context, size: size, yBase: yCenter, amplitude: waveAmplitude, waveLength: waveLength, color: baseColor)

            if isConnected {
                drawDataParticles(context: context, size: size, yCenter: yCenter, amplitude: waveAmplitude, waveLength: waveLength, color: baseColor)
            }

            drawSparks(context: context, color: baseColor)

            let txX: CGFloat = 24
            let txWaveX = txX / waveLength + phase
            let txY = yCenter + sin(txWaveX * .pi * 2) * waveAmplitude + waveModifiers(waveX: txWaveX)
            drawPortNode(context: context, center: CGPoint(x: txX, y: txY), color: baseColor, label: "TX")

            let rxX: CGFloat = size.width - 24
            let rxWaveX = rxX / waveLength + phase
            let rxY = yCenter + sin(rxWaveX * .pi * 2) * waveAmplitude + waveModifiers(waveX: rxWaveX)
            drawPortNode(context: context, center: CGPoint(x: rxX, y: rxY), color: baseColor, label: "RX")

            drawBaudLabel(context: context, size: size, color: baseColor)
        }
        .overlay(alignment: .top) {
            LinearGradient(colors: [Color(nsColor: .windowBackgroundColor), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 24)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [.clear, Color(nsColor: .windowBackgroundColor)], startPoint: .top, endPoint: .bottom)
                .frame(height: 16)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .leading) {
            LinearGradient(colors: [Color(nsColor: .windowBackgroundColor), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 40)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .trailing) {
            LinearGradient(colors: [.clear, Color(nsColor: .windowBackgroundColor)], startPoint: .leading, endPoint: .trailing)
                .frame(width: 40)
            .allowsHitTesting(false)
        }
        .onReceive(timer) { _ in
            phase += speedForBaudRate
            pulsePhase += 0.06
            for i in sparks.indices {
                sparks[i].life -= 0.035
                sparks[i].x += sparks[i].vx
                sparks[i].y += sparks[i].vy
                sparks[i].vy += 0.15
            }
            sparks.removeAll { $0.life <= 0 }
        }
        .onReceive(sparkTimer) { _ in
            if isConnected, sparks.count < 40 {
                emitSpark()
            }
        }
    }

    private func drawGrid(context: GraphicsContext, size: CGSize, color: Color) {
        var gridPath = Path()
        let spacing: CGFloat = 20
        for x in stride(from: spacing, to: size.width, by: spacing) {
            gridPath.move(to: CGPoint(x: x, y: 0))
            gridPath.addLine(to: CGPoint(x: x, y: size.height))
        }
        for y in stride(from: spacing, to: size.height, by: spacing) {
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(gridPath, with: .color(color.opacity(0.03)), lineWidth: 0.5)
    }

    private func drawFlowingWave(context: GraphicsContext, size: CGSize, yBase: CGFloat, amplitude: CGFloat, waveLength: CGFloat, color: Color, lineWidth: CGFloat, phaseOffset: CGFloat) {
        var path = Path()
        for x in stride(from: 0, through: size.width, by: 2) {
            let waveX = x / waveLength + phase + phaseOffset
            let y = yBase + sin(waveX * .pi * 2) * amplitude + cos(waveX * .pi * 3.7) * amplitude * 0.3
            if x == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }

    private func drawMainWave(context: GraphicsContext, size: CGSize, yBase: CGFloat, amplitude: CGFloat, waveLength: CGFloat, color: Color) {
        var glowPath = Path()
        for x in stride(from: 0, through: size.width, by: 2) {
            let waveX = x / waveLength + phase
            let modifiers = waveModifiers(waveX: waveX)
            let y = yBase + sin(waveX * .pi * 2) * amplitude + modifiers
            if x == 0 { glowPath.move(to: CGPoint(x: x, y: y)) }
            else { glowPath.addLine(to: CGPoint(x: x, y: y)) }
        }

        context.stroke(glowPath, with: .color(color.opacity(0.1)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        context.stroke(glowPath, with: .color(color.opacity(0.3)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        context.stroke(glowPath, with: .color(color.opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }

    private func waveModifiers(waveX: CGFloat) -> CGFloat {
        var offset: CGFloat = 0
        if config.parity != .none {
            offset += sin(waveX * 3) * 3
        }
        if config.stopBits == .two {
            offset += sin(waveX * 5) * 4
        }
        return offset
    }

    private func drawDataParticles(context: GraphicsContext, size: CGSize, yCenter: CGFloat, amplitude: CGFloat, waveLength: CGFloat, color: Color) {
        let count = particleCountForBaudRate
        for i in 0..<count {
            let t = fmod(phase * 2 + CGFloat(i) / CGFloat(count), 1.0)
            let x = t * size.width
            let waveX = x / waveLength + phase
            let modifiers = waveModifiers(waveX: waveX)
            let y = yCenter + sin(waveX * .pi * 2) * amplitude + modifiers

            let opacity = sin(t * .pi)
            let radius: CGFloat = 3 + sin(pulsePhase + CGFloat(i) * 0.7) * 1

            context.fill(
                Circle().path(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .color(color.opacity(opacity * 0.9))
            )

            let tailLen: CGFloat = 12
            var tailPath = Path()
            for step in 0..<6 {
                let tt = CGFloat(step) / 6
                let tx = x - tt * tailLen
                let twx = tx / waveLength + phase
                let ty = yCenter + sin(twx * .pi * 2) * amplitude + waveModifiers(waveX: twx)
                if step == 0 { tailPath.move(to: CGPoint(x: tx, y: ty)) }
                else { tailPath.addLine(to: CGPoint(x: tx, y: ty)) }
            }
            context.stroke(tailPath, with: .color(color.opacity(opacity * 0.3)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }

    private func drawPortNode(context: GraphicsContext, center: CGPoint, color: Color, label: String) {
        let pulseR: CGFloat = 14 + sin(pulsePhase * 1.5) * 5
        context.stroke(
            Circle().path(in: CGRect(x: center.x - pulseR, y: center.y - pulseR, width: pulseR * 2, height: pulseR * 2)),
            with: .color(color.opacity(isConnected ? 0.25 : 0.08)), lineWidth: 1.5
        )

        let midR: CGFloat = 10
        context.fill(
            Circle().path(in: CGRect(x: center.x - midR, y: center.y - midR, width: midR * 2, height: midR * 2)),
            with: .color(color.opacity(isConnected ? 0.2 : 0.08))
        )
        context.stroke(
            Circle().path(in: CGRect(x: center.x - midR, y: center.y - midR, width: midR * 2, height: midR * 2)),
            with: .color(color.opacity(0.4)), lineWidth: 1
        )

        let innerR: CGFloat = 3.5
        context.fill(
            Circle().path(in: CGRect(x: center.x - innerR, y: center.y - innerR, width: innerR * 2, height: innerR * 2)),
            with: .color(color.opacity(0.9))
        )

        let labelRect = CGRect(x: center.x - 12, y: center.y + 18, width: 24, height: 14)
        context.draw(Text(label).font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(color.opacity(0.5)), in: labelRect)
    }

    private func drawSparks(context: GraphicsContext, color: Color) {
        for spark in sparks {
            let opacity = spark.life
            let radius = spark.size * spark.life
            context.fill(
                Circle().path(in: CGRect(x: spark.x - radius, y: spark.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(color.opacity(opacity * 0.6))
            )
        }
    }

    private func drawBaudLabel(context: GraphicsContext, size: CGSize, color: Color) {
        let text = config.baudRate.display + " bps"
        let rect = CGRect(x: size.width / 2 - 40, y: 8, width: 80, height: 16)
        context.draw(Text(text).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(color.opacity(0.35)), in: rect)
    }

    private func emitSpark() {
        let x = CGFloat.random(in: 40...200)
        sparks.append(Spark(
            x: x, y: 60 + CGFloat.random(in: -5...5),
            vx: CGFloat.random(in: -0.5...0.5),
            vy: CGFloat.random(in: -2...(-0.5)),
            life: 1.0,
            size: CGFloat.random(in: 1.5...3.5)
        ))
        let rx = CGFloat.random(in: (200)...(400))
        sparks.append(Spark(
            x: rx, y: 60 + CGFloat.random(in: -5...5),
            vx: CGFloat.random(in: -0.5...0.5),
            vy: CGFloat.random(in: -2...(-0.5)),
            life: 1.0,
            size: CGFloat.random(in: 1.5...3.5)
        ))
    }

    private var waveCountForBaudRate: Int {
        switch config.baudRate {
        case .baud9600: 2; case .baud19200: 3; case .baud38400: 4; case .baud57600: 5
        case .baud115200: 6; case .baud230400: 8; case .baud460800: 10; case .baud921600: 12
        }
    }

    private var amplitudeScale: CGFloat {
        switch config.dataBits {
        case .five: 0.6; case .six: 0.75; case .seven: 0.9; case .eight: 1.0
        }
    }

    private var speedForBaudRate: CGFloat {
        switch config.baudRate {
        case .baud9600: 0.01; case .baud19200: 0.018; case .baud38400: 0.026; case .baud57600: 0.035
        case .baud115200: 0.045; case .baud230400: 0.06; case .baud460800: 0.075; case .baud921600: 0.09
        }
    }

    private var particleCountForBaudRate: Int {
        switch config.baudRate {
        case .baud9600: 4; case .baud19200: 5; case .baud38400: 6; case .baud57600: 8
        case .baud115200: 10; case .baud230400: 13; case .baud460800: 16; case .baud921600: 20
        }
    }
}

private struct Spark {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: CGFloat
    var size: CGFloat
}
