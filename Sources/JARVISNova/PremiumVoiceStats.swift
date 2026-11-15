import SwiftUI

// MARK: - Voice visualizer (5 variants)

struct PremiumVoiceVisual: View {
    let variant: Int
    let accent: Color
    let active: Bool
    let reducedMotion: Bool

    var body: some View {
        switch variant {
        case 1: VoiceOrbRadial(accent: accent, active: active, reducedMotion: reducedMotion)
        case 2: VoiceLEDEqualizer(accent: accent, active: active, reducedMotion: reducedMotion)
        case 3: VoiceAurora(accent: accent, active: active, reducedMotion: reducedMotion)
        case 4: VoiceMesh(accent: accent, active: active, reducedMotion: reducedMotion)
        default: PremiumVoiceSpectrum(accent: accent, active: active, reducedMotion: reducedMotion)
        }
    }
}

struct VoiceOrbRadial: View {
    let accent: Color
    let active: Bool
    let reducedMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: reducedMotion ? 1 : 1.0 / 30, paused: reducedMotion)) { tl in
            Canvas { context, size in
                let t = reducedMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                let energy = active ? 1.0 : 0.3
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let S = Swift.min(size.width, size.height)
                let base = S * 0.27
                let bars = 110
                for i in 0..<bars {
                    let a = Double(i) / Double(bars) * 2 * Double.pi
                    let n = abs(sin(a * 7 + t * 2.2)) * 0.55 + abs(sin(a * 3 - t * 1.4)) * 0.45
                    let len = base * 0.12 + CGFloat(n * energy) * S * 0.24
                    var line = Path()
                    line.move(to: PV.pt(c, a, base * 1.06))
                    line.addLine(to: PV.pt(c, a, base * 1.06 + len))
                    let col: Color = n > 0.7 ? Color.yellow.opacity(0.9) : accent.opacity(0.35 + n * 0.6)
                    context.stroke(line, with: .color(col), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                }
                context.drawLayer { l in
                    l.addFilter(.shadow(color: accent, radius: 18))
                    l.fill(PV.circle(c, base * 0.92), with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(0.95), accent.opacity(0.85), accent.opacity(0.18), Color.black.opacity(0.9)]),
                        center: CGPoint(x: c.x - base * 0.25, y: c.y - base * 0.3), startRadius: 0, endRadius: base * 1.1))
                }
                for k in 0..<3 {
                    var arc = Path()
                    let rot = t * (k % 2 == 0 ? 70 : -110) + Double(k) * 90
                    arc.addArc(center: c, radius: base * (0.74 + CGFloat(k) * 0.1), startAngle: .degrees(rot), endAngle: .degrees(rot + 110 - Double(k) * 20), clockwise: false)
                    context.stroke(arc, with: .color(.white.opacity(0.6 - Double(k) * 0.15)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                }
                var gloss = Path()
                gloss.addEllipse(in: CGRect(x: c.x - base * 0.5, y: c.y - base * 0.78, width: base * 0.8, height: base * 0.36))
                context.fill(gloss, with: .linearGradient(Gradient(colors: [.white.opacity(0.55), .clear]),
                                                          startPoint: CGPoint(x: c.x, y: c.y - base * 0.78), endPoint: CGPoint(x: c.x, y: c.y - base * 0.4)))
            }
        }
    }
}

struct VoiceLEDEqualizer: View {
    let accent: Color
    let active: Bool
    let reducedMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: reducedMotion ? 1 : 1.0 / 30, paused: reducedMotion)) { tl in
            Canvas { context, size in
                let t = reducedMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                let energy = active ? 1.0 : 0.3
                let colW: CGFloat = 9
                let cols = Int(size.width / colW)
                let rows = 16
                let floorY = size.height * 0.82
                let segH = (floorY - 4) / CGFloat(rows)
                for i in 0..<cols {
                    let u = Double(i) / Double(Swift.max(cols - 1, 1))
                    let env = 0.25 + 0.75 * pow(sin(u * Double.pi), 0.9)
                    let n = abs(sin(u * 17 + t * 3.3)) * 0.55 + abs(sin(u * 6 - t * 2.1)) * 0.45
                    let level = Swift.min(1, env * n * energy * 1.15)
                    let lit = Int((level * Double(rows)).rounded())
                    let x = CGFloat(i) * colW + 1
                    for r in 0..<rows {
                        let y = floorY - CGFloat(r + 1) * segH
                        let rect = CGRect(x: x, y: y + 1, width: colW - 3, height: segH - 2)
                        let frac = Double(r) / Double(rows)
                        let base: Color = frac < 0.6 ? accent : (frac < 0.85 ? Color.yellow : Color.orange)
                        let on = r < lit
                        context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(on ? base.opacity(0.95) : Color.white.opacity(0.05)))
                        if on {
                            let refl = CGRect(x: x, y: floorY + CGFloat(r) * segH * 0.55 + 3, width: colW - 3, height: segH * 0.5)
                            if refl.maxY < size.height {
                                context.fill(Path(roundedRect: refl, cornerRadius: 1), with: .color(base.opacity(0.18 * (1 - frac))))
                            }
                        }
                    }
                    let peak = Swift.min(rows - 1, lit + 1)
                    let py = floorY - CGFloat(peak + 1) * segH
                    context.fill(Path(roundedRect: CGRect(x: x, y: py + 1, width: colW - 3, height: 2.5), cornerRadius: 1),
                                 with: .color(.white.opacity(lit > 0 ? 0.9 : 0.1)))
                }
            }
        }
    }
}

struct VoiceAurora: View {
    let accent: Color
    let active: Bool
    let reducedMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: reducedMotion ? 1 : 1.0 / 30, paused: reducedMotion)) { tl in
            Canvas { context, size in
                let t = reducedMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                let energy = active ? 1.0 : 0.35
                let tints: [Color] = [accent, PV.lime, Color(red: 0.2, green: 0.95, blue: 0.75)]
                for layer in 0..<3 {
                    var x: CGFloat = 0
                    while x < size.width {
                        let u = Double(x / size.width)
                        let env = pow(sin(u * Double.pi), 0.8)
                        let top = size.height * (0.28 + 0.1 * CGFloat(layer)) + CGFloat(sin(u * 6 + t * (0.8 + Double(layer) * 0.3) + Double(layer) * 1.7) * 0.5 + sin(u * 13 - t * 1.3) * 0.25) * size.height * 0.22 * CGFloat(energy)
                        let h = size.height * (0.38 + 0.12 * CGFloat(env)) * CGFloat(0.55 + 0.45 * energy)
                        let rect = CGRect(x: x, y: top, width: 3, height: h)
                        context.fill(Path(rect), with: .linearGradient(
                            Gradient(colors: [tints[layer].opacity(0.55 * (0.4 + env * 0.6)), tints[layer].opacity(0.0)]),
                            startPoint: CGPoint(x: x, y: rect.minY), endPoint: CGPoint(x: x, y: rect.maxY)))
                        x += 3.5
                    }
                    var edge = Path()
                    for i in 0...100 {
                        let u = Double(i) / 100
                        let top = size.height * (0.28 + 0.1 * CGFloat(layer)) + CGFloat(sin(u * 6 + t * (0.8 + Double(layer) * 0.3) + Double(layer) * 1.7) * 0.5 + sin(u * 13 - t * 1.3) * 0.25) * size.height * 0.22 * CGFloat(energy)
                        let p = CGPoint(x: CGFloat(u) * size.width, y: top)
                        if i == 0 { edge.move(to: p) } else { edge.addLine(to: p) }
                    }
                    context.drawLayer { l in
                        l.addFilter(.shadow(color: tints[layer], radius: 8))
                        l.stroke(edge, with: .color(tints[layer].opacity(0.95)), lineWidth: 1.8)
                    }
                }
                for i in 0..<36 {
                    let fi = Double(i)
                    let rx = abs(sin(fi * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
                    let ry = abs(sin(fi * 78.233) * 43758.5453).truncatingRemainder(dividingBy: 1)
                    let tw = 0.2 + 0.8 * abs(sin(t + fi))
                    context.fill(PV.circle(CGPoint(x: size.width * CGFloat(rx), y: size.height * CGFloat(ry) * 0.7), 1.1), with: .color(.white.opacity(tw * 0.7)))
                }
            }
        }
    }
}

struct VoiceMesh: View {
    let accent: Color
    let active: Bool
    let reducedMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: reducedMotion ? 1 : 1.0 / 30, paused: reducedMotion)) { tl in
            Canvas { context, size in
                let t = reducedMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                let energy = active ? 1.0 : 0.3
                let rows = 15
                let cols = 56
                func point(_ row: Int, _ col: Int) -> CGPoint {
                    let r = Double(row) / Double(rows - 1)
                    let u = Double(col) / Double(cols - 1)
                    let depth = pow(r, 1.7)
                    let spread = 0.22 + 0.95 * depth
                    let x = size.width * (0.5 + (u - 0.5) * spread)
                    let env = pow(sin(u * Double.pi), 1.1)
                    let n = sin(u * 11 + t * 2.4 + r * 6) * 0.55 + sin(u * 4 - t * 1.6 - r * 3) * 0.45
                    let lift = n * env * energy * (0.1 + 0.2 * depth)
                    let y = size.height * (0.30 + 0.66 * depth) - CGFloat(lift) * size.height
                    return CGPoint(x: x, y: y)
                }
                for row in 0..<rows {
                    var line = Path()
                    for col in 0..<cols {
                        let p = point(row, col)
                        if col == 0 { line.move(to: p) } else { line.addLine(to: p) }
                    }
                    var fill = line
                    fill.addLine(to: CGPoint(x: size.width, y: size.height))
                    fill.addLine(to: CGPoint(x: 0, y: size.height))
                    fill.closeSubpath()
                    context.fill(fill, with: .color(.black.opacity(0.62)))
                    let near = Double(row) / Double(rows - 1)
                    context.drawLayer { l in
                        l.addFilter(.shadow(color: accent, radius: 3 + 4 * near))
                        l.stroke(line, with: .color(accent.opacity(0.25 + 0.7 * near)), lineWidth: 0.7 + 1.1 * near)
                    }
                }
                for col in stride(from: 0, to: cols, by: 4) {
                    var v = Path()
                    for row in 0..<rows {
                        let p = point(row, col)
                        if row == 0 { v.move(to: p) } else { v.addLine(to: p) }
                    }
                    context.stroke(v, with: .color(accent.opacity(0.18)), lineWidth: 0.6)
                }
                let sunC = CGPoint(x: size.width / 2, y: size.height * 0.22)
                context.drawLayer { l in
                    l.addFilter(.shadow(color: accent, radius: 14))
                    l.fill(PV.circle(sunC, size.height * 0.11), with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(0.9), accent.opacity(0.55), accent.opacity(0.05)]),
                        center: sunC, startRadius: 0, endRadius: size.height * 0.12))
                }
            }
        }
    }
}

// MARK: - Stats variants 1...4

struct Spark: View {
    let values: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            var points: [CGPoint] = []
            for (i, v) in values.enumerated() {
                points.append(CGPoint(x: CGFloat(i) / CGFloat(values.count - 1) * size.width,
                                      y: size.height - CGFloat(Swift.min(100, Swift.max(0, v)) / 100) * (size.height - 4) - 2))
            }
            var line = Path()
            for (i, p) in points.enumerated() { if i == 0 { line.move(to: p) } else { line.addLine(to: p) } }
            var area = line
            area.addLine(to: CGPoint(x: size.width, y: size.height))
            area.addLine(to: CGPoint(x: 0, y: size.height))
            area.closeSubpath()
            context.fill(area, with: .linearGradient(Gradient(colors: [color.opacity(0.4), color.opacity(0)]),
                                                     startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)))
            context.drawLayer { l in
                l.addFilter(.shadow(color: color, radius: 4))
                l.stroke(line, with: .color(color), lineWidth: 1.6)
            }
        }
    }
}

struct StatsVariantView: View {
    let variant: Int
    @ObservedObject var monitor: SystemMonitor
    let accent: Color

    private var ready: Bool { monitor.lastUpdated != nil }
    private func pct(_ v: Double) -> String { ready ? "\(Int(v))%" : "—" }

    var body: some View {
        switch variant {
        case 1: concentric
        case 2: ledBars
        case 3: tiles
        default: speedometers
        }
    }

    private var legend: [(String, Double, String, Color)] {
        [("CPU", monitor.cpuPercent, "Процессор", accent),
         ("RAM", monitor.memoryPercent, String(format: "%.1f / %.1f GB", monitor.memoryUsedGB, monitor.memoryTotalGB), PV.lime),
         ("SSD", monitor.diskPercent, String(format: "%.0f GB свободно", monitor.diskFreeGB), Color.white)]
    }

    @ViewBuilder private var concentric: some View {
        let items = legend
        HStack(spacing: 14) {
            ZStack {
                Canvas { context, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let R = Swift.min(size.width, size.height) / 2 - 4
                    for (i, item) in items.enumerated() {
                        let r = R * (0.95 - CGFloat(i) * 0.2)
                        context.stroke(PV.circle(c, r), with: .color(.white.opacity(0.08)), lineWidth: 10)
                        var arc = Path()
                        let frac = Swift.min(1, Swift.max(0, item.1 / 100))
                        arc.addArc(center: c, radius: r, startAngle: .degrees(-90), endAngle: .degrees(-90 + 270 * frac), clockwise: false)
                        context.drawLayer { l in
                            l.addFilter(.shadow(color: item.3, radius: 6))
                            l.stroke(arc, with: .color(item.3), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        }
                    }
                }
                VStack(spacing: 0) {
                    Text(pct(monitor.cpuPercent)).font(.system(size: 26, weight: .light, design: .rounded)).monospacedDigit()
                    Text("CPU").font(.system(size: 9, weight: .bold)).foregroundStyle(accent)
                }
            }
            .frame(width: 150, height: 150)
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 8) {
                        Circle().fill(item.3).frame(width: 8, height: 8).shadow(color: item.3, radius: 4)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(item.0)  \(pct(item.1))").font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
                            Text(item.2).font(.system(size: 9)).foregroundStyle(.white.opacity(0.55))
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }.frame(maxHeight: .infinity)
    }

    private func ledColumn(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(spacing: 5) {
            Canvas { context, size in
                let rows = 16
                let segH = size.height / CGFloat(rows)
                let lit = Int((Swift.min(100, Swift.max(0, value)) / 100 * Double(rows)).rounded())
                for r in 0..<rows {
                    let y = size.height - CGFloat(r + 1) * segH
                    let rect = CGRect(x: 0, y: y + 1, width: size.width, height: segH - 2)
                    let frac = Double(r) / Double(rows)
                    let base: Color = frac < 0.6 ? color : (frac < 0.85 ? Color.yellow : Color.orange)
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(r < lit ? base : Color.white.opacity(0.07)))
                }
            }
            .frame(width: 26).frame(maxHeight: .infinity)
            Text(pct(value)).font(.system(size: 11, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(title).font(.system(size: 8, weight: .bold)).foregroundStyle(color)
        }
    }

    private var ledBars: some View {
        HStack(spacing: 14) {
            HStack(spacing: 14) {
                ledColumn("CPU", monitor.cpuPercent, accent)
                ledColumn("RAM", monitor.memoryPercent, PV.lime)
                ledColumn("SSD", monitor.diskPercent, Color.white)
            }
            Rectangle().fill(.white.opacity(0.12)).frame(width: 1)
            VStack(alignment: .leading, spacing: 8) {
                Label(monitor.networkDownLabel, systemImage: "arrow.down.circle.fill").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(accent)
                Label(monitor.networkUpLabel, systemImage: "arrow.up.circle.fill").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(PV.lime)
                Spark(values: monitor.samples.map { $0.cpu }, color: accent).frame(maxHeight: .infinity)
                Text(String(format: "%.1f / %.1f GB", monitor.memoryUsedGB, monitor.memoryTotalGB)).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
            }
        }.frame(maxHeight: .infinity)
    }

    private func tile(_ title: String, _ icon: String, _ value: String, _ values: [Double], _ color: Color) -> some View {
        ZStack(alignment: .bottom) {
            Spark(values: values, color: color).frame(height: 34).padding(.horizontal, 2).opacity(0.9)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: icon).font(.system(size: 10)).foregroundStyle(color)
                    Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.65))
                }
                Text(value).font(.system(size: 20, weight: .light, design: .rounded)).monospacedDigit()
                Spacer(minLength: 0)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(9)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.35), lineWidth: 0.9))
    }

    private var tiles: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                tile("CPU", "cpu", pct(monitor.cpuPercent), monitor.samples.map { $0.cpu }, accent)
                tile("RAM", "memorychip", pct(monitor.memoryPercent), monitor.samples.map { $0.memory }, PV.lime)
            }
            HStack(spacing: 8) {
                tile("SSD", "internaldrive", pct(monitor.diskPercent), Array(repeating: monitor.diskPercent, count: 12), Color.white)
                tile("СЕТЬ ↓", "wifi", monitor.networkDownLabel, monitor.samples.map { $0.cpu * 0.6 }, Color(red: 0.2, green: 0.95, blue: 0.75))
            }
        }.frame(maxHeight: .infinity)
    }

    private func arcGauge(_ title: String, _ value: Double, _ color: Color) -> some View {
        ZStack {
            Canvas { context, size in
                let c = CGPoint(x: size.width / 2, y: size.height * 0.56)
                let R = Swift.min(size.width, size.height * 1.05) / 2 - 6
                let frac = Swift.min(1, Swift.max(0, value / 100))
                var track = Path()
                track.addArc(center: c, radius: R, startAngle: .degrees(135), endAngle: .degrees(405), clockwise: false)
                context.stroke(track, with: .color(.white.opacity(0.1)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                var arc = Path()
                arc.addArc(center: c, radius: R, startAngle: .degrees(135), endAngle: .degrees(135 + 270 * frac), clockwise: false)
                context.drawLayer { l in
                    l.addFilter(.shadow(color: color, radius: 7))
                    l.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                }
                for i in 0...10 {
                    let a = (135 + 27 * Double(i)) * Double.pi / 180
                    var tick = Path()
                    tick.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * (R - 11), y: c.y + CGFloat(sin(a)) * (R - 11)))
                    tick.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * (R - (i % 5 == 0 ? 20 : 16)), y: c.y + CGFloat(sin(a)) * (R - (i % 5 == 0 ? 20 : 16))))
                    context.stroke(tick, with: .color(.white.opacity(0.5)), lineWidth: 1)
                }
                let na = (135 + 270 * frac) * Double.pi / 180
                var needle = Path()
                needle.move(to: c)
                needle.addLine(to: CGPoint(x: c.x + CGFloat(cos(na)) * (R - 18), y: c.y + CGFloat(sin(na)) * (R - 18)))
                context.drawLayer { l in
                    l.addFilter(.shadow(color: color, radius: 4))
                    l.stroke(needle, with: .color(.white), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                }
                context.fill(PV.circle(c, 5), with: .color(color))
            }
            VStack(spacing: 0) {
                Spacer()
                Text(pct(value)).font(.system(size: 16, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(color)
            }.padding(.bottom, 2)
        }
    }

    private var speedometers: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                arcGauge("CPU", monitor.cpuPercent, accent)
                arcGauge("RAM", monitor.memoryPercent, PV.lime)
            }.frame(maxHeight: .infinity)
            HStack(spacing: 8) {
                Image(systemName: "internaldrive.fill").font(.system(size: 11)).foregroundStyle(.white.opacity(0.8))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule().fill(LinearGradient(colors: [accent.opacity(0.4), .white], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(Swift.min(100, monitor.diskPercent) / 100))
                    }
                }.frame(height: 6)
                Text("SSD \(pct(monitor.diskPercent))").font(.system(size: 10, weight: .semibold, design: .monospaced))
            }
        }.frame(maxHeight: .infinity)
    }
}