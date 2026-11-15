import SwiftUI

// MARK: - Detailed metal clock with skeleton gears

struct AnalogClockFace: View {
    let date: Date
    let accent: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24)) { timeline in
            Canvas { context, size in
                var c = context
                Self.render(&c, size: size, now: timeline.date, accent: accent)
            }
        }
        .accessibilityLabel("Аналоговые часы")
    }

    private static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    private static func pt(_ c: CGPoint, _ angle: Double, _ r: CGFloat) -> CGPoint {
        CGPoint(x: c.x + CGFloat(sin(angle)) * r, y: c.y - CGFloat(cos(angle)) * r)
    }

    private static func gear(center: CGPoint, outer: CGFloat, inner: CGFloat, teeth: Int, rotation: Double) -> Path {
        var p = Path()
        let n = teeth * 4
        for i in 0..<n {
            let a = rotation + Double(i) / Double(n) * 2 * Double.pi
            let tooth = (i % 4 == 1 || i % 4 == 2)
            let point = pt(center, a, tooth ? outer : inner)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        p.addPath(circle(center, inner * 0.38))
        return p
    }

    private static func hand(center c: CGPoint, angle: Double, length: CGFloat, width: CGFloat, tail: CGFloat) -> Path {
        let dir = CGPoint(x: CGFloat(sin(angle)), y: -CGFloat(cos(angle)))
        let perp = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle)))
        func p(_ along: CGFloat, _ side: CGFloat) -> CGPoint {
            CGPoint(x: c.x + dir.x * along + perp.x * side, y: c.y + dir.y * along + perp.y * side)
        }
        var path = Path()
        path.move(to: p(-tail, 0))
        path.addLine(to: p(-tail * 0.2, width * 0.5))
        path.addLine(to: p(length * 0.22, width * 0.5))
        path.addLine(to: p(length, 0))
        path.addLine(to: p(length * 0.22, -width * 0.5))
        path.addLine(to: p(-tail * 0.2, -width * 0.5))
        path.closeSubpath()
        return path
    }

    private static func render(_ context: inout GraphicsContext, size: CGSize, now: Date, accent: Color) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let R = min(size.width, size.height) / 2 - 3
        let t = now.timeIntervalSinceReferenceDate
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute, .second, .nanosecond], from: now)
        let sec = Double(comps.second ?? 0) + Double(comps.nanosecond ?? 0) / 1_000_000_000
        let min = Double(comps.minute ?? 0) + sec / 60
        let hr = Double(comps.hour ?? 0).truncatingRemainder(dividingBy: 12) + min / 60

        // Bezel: conic brushed steel with drop shadow
        context.drawLayer { l in
            l.addFilter(.shadow(color: .black.opacity(0.75), radius: R * 0.09, x: 0, y: R * 0.06))
            l.fill(circle(c, R), with: .conicGradient(
                Gradient(colors: [.white, Color(white: 0.38), Color(white: 0.92), Color(white: 0.16), .white, Color(white: 0.5), Color(white: 0.85), .white]),
                center: c, angle: .degrees(-35)))
        }
        context.stroke(circle(c, R), with: .color(.white.opacity(0.55)), lineWidth: 1)
        context.stroke(circle(c, R * 0.955), with: .color(.black.opacity(0.65)), lineWidth: 2)
        // Screws on the bezel
        for i in 0..<8 {
            let sp = pt(c, Double(i) * Double.pi / 4 + 0.39, R * 0.935)
            context.fill(circle(sp, R * 0.018), with: .color(Color(white: 0.12)))
            context.stroke(circle(sp, R * 0.018), with: .color(.white.opacity(0.5)), lineWidth: 0.6)
        }
        // Glowing accent ring
        context.drawLayer { l in
            l.addFilter(.shadow(color: accent, radius: R * 0.05))
            l.stroke(circle(c, R * 0.905), with: .color(accent.opacity(0.9)), lineWidth: 1.4)
        }

        // Dial
        let dialR = R * 0.88
        context.fill(circle(c, dialR), with: .radialGradient(
            Gradient(colors: [Color(white: 0.17), Color(white: 0.04)]),
            center: CGPoint(x: c.x - R * 0.2, y: c.y - R * 0.25), startRadius: 0, endRadius: dialR * 1.3))
        for i in 1..<22 {
            context.stroke(circle(c, dialR * CGFloat(i) / 22), with: .color(.white.opacity(i % 2 == 0 ? 0.035 : 0.015)), lineWidth: 0.6)
        }

        // Skeleton window with turning gears
        let winR = R * 0.55
        context.fill(circle(c, winR), with: .color(.black.opacity(0.62)))
        context.drawLayer { l in
            l.clip(to: circle(c, winR))
            let gears: [(CGPoint, CGFloat, CGFloat, Int, Double)] = [
                (CGPoint(x: c.x - R * 0.17, y: c.y + R * 0.08), R * 0.32, R * 0.27, 16, t * 0.12),
                (CGPoint(x: c.x + R * 0.22, y: c.y + R * 0.15), R * 0.23, R * 0.19, 12, -t * 0.16 + 0.26),
                (CGPoint(x: c.x + R * 0.02, y: c.y - R * 0.27), R * 0.18, R * 0.145, 10, t * 0.24),
                (CGPoint(x: c.x - R * 0.30, y: c.y - R * 0.22), R * 0.12, R * 0.095, 8, -t * 0.3)
            ]
            for g in gears {
                let path = gear(center: g.0, outer: g.1, inner: g.2, teeth: g.3, rotation: g.4)
                l.drawLayer { s in
                    s.addFilter(.shadow(color: .black.opacity(0.8), radius: 3, x: 1.5, y: 2))
                    s.fill(path, with: .linearGradient(Gradient(colors: [Color(white: 0.46), Color(white: 0.09)]),
                                                       startPoint: CGPoint(x: g.0.x - g.1, y: g.0.y - g.1),
                                                       endPoint: CGPoint(x: g.0.x + g.1, y: g.0.y + g.1)), style: FillStyle(eoFill: true))
                }
                l.stroke(path, with: .color(.white.opacity(0.22)), lineWidth: 0.6)
                l.fill(circle(g.0, g.2 * 0.14), with: .color(accent.opacity(0.85)))
                for spoke in 0..<4 {
                    let a = g.4 + Double(spoke) * Double.pi / 2
                    var sp = Path()
                    sp.move(to: pt(g.0, a, g.2 * 0.38))
                    sp.addLine(to: pt(g.0, a, g.2 * 0.86))
                    l.stroke(sp, with: .color(.black.opacity(0.7)), lineWidth: g.2 * 0.16)
                }
            }
        }
        context.stroke(circle(c, winR), with: .color(.white.opacity(0.35)), lineWidth: 1.2)
        context.stroke(circle(c, winR + 2), with: .color(.black.opacity(0.7)), lineWidth: 1.5)

        // Minute track and hour markers
        for i in 0..<60 {
            let a = Double(i) * Double.pi / 30
            let major = i % 5 == 0
            let cardinal = i % 15 == 0
            var tick = Path()
            tick.move(to: pt(c, a, dialR * 0.965))
            tick.addLine(to: pt(c, a, dialR * (major ? 0.885 : 0.925)))
            context.stroke(tick, with: .color(cardinal ? accent : (major ? .white.opacity(0.95) : .white.opacity(0.5))),
                           lineWidth: cardinal ? 2.6 : (major ? 1.8 : 0.8))
        }
        // Roman numerals
        let numerals = ["XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
        for (i, n) in numerals.enumerated() {
            let a = Double(i) * Double.pi / 6
            let p = pt(c, a, R * 0.715)
            context.drawLayer { l in
                l.addFilter(.shadow(color: .black.opacity(0.9), radius: 1.5, x: 0.8, y: 1))
                l.draw(Text(n).font(.system(size: R * 0.105, weight: .semibold, design: .serif)).foregroundColor(Color(white: 0.93)),
                       at: p, anchor: .center)
            }
        }
        context.draw(Text("JARVIS").font(.system(size: R * 0.05, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.55)),
                     at: CGPoint(x: c.x, y: c.y + R * 0.42), anchor: .center)

        // Hands (metal, with shadow)
        let handFill = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [.white, Color(white: 0.55), .white]),
            startPoint: CGPoint(x: c.x - R * 0.1, y: c.y - R * 0.1), endPoint: CGPoint(x: c.x + R * 0.1, y: c.y + R * 0.1))
        let hourPath = hand(center: c, angle: hr * Double.pi / 6, length: R * 0.46, width: R * 0.085, tail: R * 0.1)
        let minPath = hand(center: c, angle: min * Double.pi / 30, length: R * 0.72, width: R * 0.06, tail: R * 0.12)
        context.drawLayer { l in
            l.addFilter(.shadow(color: .black.opacity(0.8), radius: 4, x: 2, y: 4))
            l.fill(hourPath, with: handFill)
            l.fill(minPath, with: handFill)
        }
        context.stroke(hourPath, with: .color(.black.opacity(0.55)), lineWidth: 0.7)
        context.stroke(minPath, with: .color(.black.opacity(0.55)), lineWidth: 0.7)

        let sa = sec * Double.pi / 30
        var secLine = Path()
        secLine.move(to: pt(c, sa, -R * 0.2))
        secLine.addLine(to: pt(c, sa, R * 0.8))
        context.drawLayer { l in
            l.addFilter(.shadow(color: accent, radius: 5))
            l.stroke(secLine, with: .color(accent), lineWidth: R * 0.014)
            l.fill(circle(pt(c, sa, -R * 0.17), R * 0.03), with: .color(accent))
        }

        // Center cap
        context.drawLayer { l in
            l.addFilter(.shadow(color: .black.opacity(0.7), radius: 3, y: 2))
            l.fill(circle(c, R * 0.062), with: .linearGradient(Gradient(colors: [.white, Color(white: 0.3)]),
                                                               startPoint: CGPoint(x: c.x - R * 0.06, y: c.y - R * 0.06),
                                                               endPoint: CGPoint(x: c.x + R * 0.06, y: c.y + R * 0.06)))
        }
        context.drawLayer { l in
            l.addFilter(.shadow(color: accent, radius: 4))
            l.fill(circle(c, R * 0.03), with: .color(accent))
        }

        // Glass reflection
        context.drawLayer { l in
            l.clip(to: circle(c, dialR))
            var gl = Path()
            gl.move(to: CGPoint(x: c.x - dialR, y: c.y - dialR * 0.1))
            gl.addQuadCurve(to: CGPoint(x: c.x + dialR * 0.15, y: c.y - dialR), control: CGPoint(x: c.x - dialR * 0.55, y: c.y - dialR * 0.75))
            gl.addLine(to: CGPoint(x: c.x - dialR, y: c.y - dialR))
            gl.closeSubpath()
            l.fill(gl, with: .linearGradient(Gradient(colors: [.white.opacity(0.2), .white.opacity(0.0)]),
                                             startPoint: CGPoint(x: c.x - dialR * 0.7, y: c.y - dialR * 0.8),
                                             endPoint: CGPoint(x: c.x - dialR * 0.2, y: c.y - dialR * 0.2)))
        }
    }
}

// MARK: - Voice spectrum (waves + bars + dotted particles)

struct PremiumVoiceSpectrum: View {
    let accent: Color
    let active: Bool
    let reducedMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: reducedMotion ? 1 : 1.0 / 30, paused: reducedMotion)) { timeline in
            Canvas { context, size in
                let t = reducedMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let energy = active ? 1.0 : 0.34
                let midY = size.height / 2
                let step: CGFloat = 7
                let count = Int(size.width / step)

                // Vertical spectrum bars
                for i in 0..<count {
                    let u = Double(i) / Double(Swift.max(count - 1, 1))
                    let env = pow(sin(u * Double.pi), 1.4)
                    let n = abs(sin(u * 23 + t * 3.1)) * 0.6 + abs(sin(u * 9 - t * 1.7)) * 0.4
                    let h = CGFloat(env * n * energy) * size.height * 0.66 + 2
                    let rect = CGRect(x: CGFloat(i) * step, y: midY - h / 2, width: 2.6, height: h)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1.3),
                                 with: .linearGradient(Gradient(colors: [accent.opacity(0.95), Color.yellow.opacity(0.65), accent.opacity(0.2)]),
                                                       startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)))
                }

                func waveY(_ layer: Int, _ u: Double) -> CGFloat {
                    let phase = t * (active ? 2.6 : 0.6)
                    let env = 0.2 + 0.8 * pow(sin(u * Double.pi), 0.8)
                    let w = sin(u * 11 + phase + Double(layer) * 0.34) * 0.55 + sin(u * 23 - phase * 0.8 + Double(layer) * 0.5) * 0.2
                    return midY + CGFloat(w * env * energy) * size.height * (0.26 + Double(layer) * 0.018)
                }
                // Wave ribbons
                for layer in 0..<8 {
                    var path = Path()
                    for i in 0...120 {
                        let u = Double(i) / 120
                        let p = CGPoint(x: CGFloat(u) * size.width, y: waveY(layer, u))
                        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }
                    if layer == 0 {
                        context.drawLayer { l in
                            l.addFilter(.shadow(color: accent, radius: 10))
                            l.stroke(path, with: .color(.white.opacity(0.95)), lineWidth: 2.4)
                        }
                    } else {
                        context.stroke(path, with: .color(accent.opacity(0.62 - Double(layer) * 0.055)), lineWidth: 1)
                    }
                }
                // Dotted particles riding the waves
                for layer in 1..<6 {
                    var i = 0
                    while i < Int(size.width) {
                        let u = Double(i) / Double(size.width)
                        let y = waveY(layer, u) + CGFloat(sin(u * 40 + t * 2 + Double(layer))) * 5
                        let dot = CGRect(x: CGFloat(i), y: y - 1, width: 2, height: 2)
                        context.fill(Path(ellipseIn: dot), with: .color(Color.yellow.opacity(0.55)))
                        i += 13
                    }
                }
            }
        }
        .accessibilityLabel(active ? "Голосовой спектр активен" : "Голосовой спектр в режиме ожидания")
    }
}

// MARK: - Ring gauge

struct RingGauge: View {
    let title: String
    let value: Double
    let valueText: String
    let detail: String
    let accent: Color

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle().stroke(.white.opacity(0.10), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(Swift.min(Swift.max(value, 0), 100) / 100))
                    .stroke(AngularGradient(colors: [accent.opacity(0.25), accent, .white], center: .center),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: accent.opacity(0.85), radius: 5)
                    .animation(.easeOut(duration: 0.6), value: value)
                Text(valueText).font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11, weight: .bold)).foregroundStyle(accent)
                Text(detail).font(.system(size: 8, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.14), lineWidth: 0.8))
    }
}

struct VoiceStatCell: View {
    let icon: String
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle().stroke(accent.opacity(0.7), lineWidth: 1.4).frame(width: 34, height: 34)
                    .shadow(color: accent.opacity(0.6), radius: 4)
                Image(systemName: icon).font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                Text(value).font(.system(size: 14, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
    }
}