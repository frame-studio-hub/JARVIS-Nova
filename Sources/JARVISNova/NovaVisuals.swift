import SwiftUI
import AppKit

struct NovaBackdrop: View {
    let accent: Color
    let reducedMotion: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.018, green: 0.022, blue: 0.025),
                    Color(red: 0.025, green: 0.045, blue: 0.035),
                    Color(red: 0.008, green: 0.012, blue: 0.014)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [accent.opacity(0.12), .clear],
                center: .init(x: 0.48, y: 0.32),
                startRadius: 10,
                endRadius: 620
            )

            Canvas { context, size in
                var grid = Path()
                stride(from: 0.0, through: size.width, by: 64.0).forEach { x in
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                stride(from: 0.0, through: size.height, by: 64.0).forEach { y in
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(accent.opacity(0.022)), lineWidth: 0.45)
                for i in 0..<28 {
                    let x = CGFloat((i * 97) % 997) / 997 * size.width
                    let y = CGFloat((i * 173) % 991) / 991 * size.height
                    let r: CGFloat = i % 7 == 0 ? 1.3 : 0.6
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                                 with: .color(.white.opacity(i % 5 == 0 ? 0.16 : 0.055)))
                }
            }

            LinearGradient(
                colors: [.black.opacity(0.04), .clear, .black.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct NovaCoreView: View {
    let accent: Color
    let active: Bool
    let reducedMotion: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(active ? 0.13 : 0.075))
                 .frame(width: 300, height: 300)
                .blur(radius: 36)
                .scaleEffect(1.0)

            Circle()
                .stroke(.white.opacity(0.055), lineWidth: 1)
                 .frame(width: 410, height: 410)

            Circle()
                .stroke(accent.opacity(0.12), lineWidth: 1)
                 .frame(width: 365, height: 365)

            NovaOrbitLayer(accent: accent, reducedMotion: reducedMotion)
                 .frame(width: 420, height: 420)
                .allowsHitTesting(false)

            Circle()
                .stroke(accent.opacity(0.20), lineWidth: 1)
                 .frame(width: 275, height: 275)

            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 1)
                 .frame(width: 235, height: 235)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.30), accent.opacity(0.08), .black.opacity(0.8)],
                        center: .center,
                        startRadius: 2,
                        endRadius: 102
                    )
                )
                 .frame(width: 210, height: 210)
                .overlay {
                    Circle().stroke(accent.opacity(0.55), lineWidth: 1.2)
                    Circle().stroke(.white.opacity(0.12), lineWidth: 0.7).padding(7)
                }
                .shadow(color: accent.opacity(0.22), radius: 24)

            JarvisShoulderArmor()
                .fill(LinearGradient(colors: [Color(white: 0.25), Color(white: 0.055), .black],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    JarvisShoulderArmor().stroke(.white.opacity(0.24), lineWidth: 1.1)
                }
                .overlay {
                    Path { p in
                        p.move(to: CGPoint(x: 28, y: 95))
                        p.addLine(to: CGPoint(x: 82, y: 58))
                        p.move(to: CGPoint(x: 252, y: 95))
                        p.addLine(to: CGPoint(x: 198, y: 58))
                        p.move(to: CGPoint(x: 88, y: 116))
                        p.addLine(to: CGPoint(x: 108, y: 132))
                        p.move(to: CGPoint(x: 192, y: 116))
                        p.addLine(to: CGPoint(x: 172, y: 132))
                    }.stroke(accent.opacity(0.55), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                }
                 .frame(width: 400, height: 205)
                 .offset(y: 136)
                .shadow(color: .black.opacity(0.55), radius: 16, y: 8)

            JarvisHelmetMark(accent: accent)
                 .frame(width: 198, height: 278)
                .shadow(color: accent.opacity(0.42), radius: 20)
                .scaleEffect(1.0)

            VStack {
                HStack {
                    Text("NOVA / CORE")
                    Spacer()
                    Circle().fill(active ? .orange : accent).frame(width: 5, height: 5)
                }
                Spacer()
                HStack {
                    Text("NEURAL LINK")
                    Spacer()
                    Text(active ? "BUSY" : "READY")
                }
            }
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(accent.opacity(0.72))
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
             .frame(width: 400, height: 400)
        }
        .frame(width: 420, height: 420)
        .animation(.easeInOut(duration: 0.45), value: active)
    }
}

struct NovaSectionLabel: View {
    let title: String
    let detail: String
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 3, height: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.9))
                Text(detail.uppercased())
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(accent.opacity(0.6))
            }
            Spacer()
        }
    }
}


private struct NovaOrbitLayer: NSViewRepresentable {
    let accent: Color
    let reducedMotion: Bool

    func makeNSView(context: Context) -> NovaOrbitNSView {
        let view = NovaOrbitNSView()
        view.wantsLayer = true
        view.configure(accent: NSColor(accent), reducedMotion: reducedMotion)
        return view
    }

    func updateNSView(_ view: NovaOrbitNSView, context: Context) {
        view.configure(accent: NSColor(accent), reducedMotion: reducedMotion)
    }
}

private final class NovaOrbitNSView: NSView {
    private var accentColor = NSColor.systemGreen
    private var reduceMotion = false
    private var configuredSize = CGSize.zero

    override var isFlipped: Bool { true }

    override func makeBackingLayer() -> CALayer {
        let root = CALayer()
        root.backgroundColor = NSColor.clear.cgColor
        return root
    }

    func configure(accent: NSColor, reducedMotion: Bool) {
        let changed = accent != accentColor || reducedMotion != reduceMotion
        accentColor = accent
        reduceMotion = reducedMotion
        if changed || configuredSize != bounds.size { rebuild() }
    }

    override func layout() {
        super.layout()
        if configuredSize != bounds.size { rebuild() }
    }

    private func rebuild() {
        guard bounds.width > 0, bounds.height > 0, let root = layer else { return }
        configuredSize = bounds.size
        root.sublayers?.forEach { $0.removeFromSuperlayer() }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let diameter = min(bounds.width, bounds.height) - 10
        let rect = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                          width: diameter, height: diameter)
        let path = CGPath(ellipseIn: rect, transform: nil)

        // Precision radial ticks: every fourth marker is emphasized like the HUD reference.
        let tickPath = CGMutablePath()
        for index in 0..<96 {
            let angle = CGFloat(index) * .pi * 2 / 96
            let inner = diameter * (index % 4 == 0 ? 0.455 : 0.468)
            let outer = diameter * 0.492
            tickPath.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
            tickPath.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
        }
        let ticks = CAShapeLayer()
        ticks.frame = bounds
        ticks.path = tickPath
        ticks.fillColor = NSColor.clear.cgColor
        ticks.strokeColor = accentColor.withAlphaComponent(0.52).cgColor
        ticks.lineWidth = 0.75
        root.addSublayer(ticks)

        let track = CAShapeLayer()
        track.frame = bounds
        track.path = path
        track.fillColor = NSColor.clear.cgColor
        track.strokeColor = accentColor.withAlphaComponent(0.13).cgColor
        track.lineWidth = 1.2
        root.addSublayer(track)

        let orbit = CAShapeLayer()
        orbit.frame = bounds
        orbit.path = path
        orbit.fillColor = NSColor.clear.cgColor
        orbit.strokeColor = NSColor.white.withAlphaComponent(0.82).cgColor
        orbit.lineWidth = 2.1
        orbit.lineCap = .round
        orbit.shadowColor = accentColor.cgColor
        orbit.shadowRadius = 8
        orbit.shadowOpacity = 0.62
        orbit.shadowOffset = .zero
        orbit.strokeStart = 0.08
        orbit.strokeEnd = 0.36
        root.addSublayer(orbit)

        let dashed = CAShapeLayer()
        dashed.frame = bounds
        dashed.path = path
        dashed.fillColor = NSColor.clear.cgColor
        dashed.strokeColor = accentColor.withAlphaComponent(0.78).cgColor
        dashed.lineWidth = 1.15
        dashed.lineDashPattern = [3, 8]
        dashed.strokeStart = 0.48
        dashed.strokeEnd = 0.80
        root.addSublayer(dashed)

        let innerRect = rect.insetBy(dx: diameter * 0.105, dy: diameter * 0.105)
        let innerArc = CAShapeLayer()
        innerArc.frame = bounds
        innerArc.path = CGPath(ellipseIn: innerRect, transform: nil)
        innerArc.fillColor = NSColor.clear.cgColor
        innerArc.strokeColor = NSColor.white.withAlphaComponent(0.20).cgColor
        innerArc.lineWidth = 0.8
        innerArc.lineDashPattern = [1, 7]
        innerArc.strokeStart = 0.12
        innerArc.strokeEnd = 0.88
        root.addSublayer(innerArc)

        let dot = CAShapeLayer()
        let dotRect = CGRect(x: center.x - 2.5, y: rect.minY - 2.5, width: 5, height: 5)
        dot.path = CGPath(ellipseIn: dotRect, transform: nil)
        dot.fillColor = accentColor.cgColor
        dot.shadowColor = accentColor.cgColor
        dot.shadowRadius = 7
        dot.shadowOpacity = 0.9
        root.addSublayer(dot)

        guard !reduceMotion else { return }
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = Double.pi * 2
        spin.duration = 72
        spin.repeatCount = .infinity
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        orbit.add(spin, forKey: "nova-orbit-spin")
        let glowPulse = CABasicAnimation(keyPath: "shadowOpacity")
        glowPulse.fromValue = 0.25
        glowPulse.toValue = 0.9
        glowPulse.duration = 2.6
        glowPulse.autoreverses = true
        glowPulse.repeatCount = .infinity
        glowPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        orbit.add(glowPulse, forKey: "nova-orbit-glow")

        let reverse = CABasicAnimation(keyPath: "transform.rotation.z")
        reverse.fromValue = 0
        reverse.toValue = -Double.pi * 2
        reverse.duration = 96
        reverse.repeatCount = .infinity
        reverse.timingFunction = CAMediaTimingFunction(name: .linear)
        dashed.add(reverse, forKey: "nova-orbit-reverse")
        dot.add(reverse, forKey: "nova-orbit-dot")

        let innerSpin = CABasicAnimation(keyPath: "transform.rotation.z")
        innerSpin.fromValue = 0
        innerSpin.toValue = Double.pi * 2
        innerSpin.duration = 54
        innerSpin.repeatCount = .infinity
        innerSpin.timingFunction = CAMediaTimingFunction(name: .linear)
        innerArc.add(innerSpin, forKey: "nova-inner-counter-orbit")

        let tickPulse = CABasicAnimation(keyPath: "opacity")
        tickPulse.fromValue = 0.42
        tickPulse.toValue = 0.95
        tickPulse.duration = 3.2
        tickPulse.autoreverses = true
        tickPulse.repeatCount = .infinity
        ticks.add(tickPulse, forKey: "nova-tick-pulse")
    }
}


// A Core Animation waveform: bars animate on the render server, not through SwiftUI redraws.
struct HardwareWaveform: NSViewRepresentable {
    let accent: Color
    let active: Bool
    let reducedMotion: Bool
    let compact: Bool

    func makeNSView(context: Context) -> NovaWaveformNSView {
        let view = NovaWaveformNSView()
        view.wantsLayer = true
        view.configure(accent: NSColor(accent), active: active,
                       reducedMotion: reducedMotion, compact: compact)
        return view
    }

    func updateNSView(_ view: NovaWaveformNSView, context: Context) {
        view.configure(accent: NSColor(accent), active: active,
                       reducedMotion: reducedMotion, compact: compact)
    }
}

final class NovaWaveformNSView: NSView {
    private var accentColor = NSColor.systemGreen
    private var active = false
    private var reduceMotion = false
    private var compact = false
    private var configuredSize = CGSize.zero

    override var isFlipped: Bool { true }

    override func makeBackingLayer() -> CALayer {
        let root = CALayer()
        root.backgroundColor = NSColor.clear.cgColor
        return root
    }

    func configure(accent: NSColor, active: Bool, reducedMotion: Bool, compact: Bool) {
        let changed = accent != accentColor || active != self.active ||
            reducedMotion != reduceMotion || compact != self.compact
        accentColor = accent
        self.active = active
        reduceMotion = reducedMotion
        self.compact = compact
        if changed || configuredSize != bounds.size { rebuild() }
    }

    override func layout() {
        super.layout()
        if configuredSize != bounds.size { rebuild() }
    }

    private func rebuild() {
        guard bounds.width > 0, bounds.height > 0, let root = layer else { return }
        configuredSize = bounds.size
        root.sublayers?.forEach { $0.removeFromSuperlayer() }

        let count = compact ? 22 : 44
        let gap: CGFloat = compact ? 3.0 : 4.0
        let barWidth = max(1.5, (bounds.width - CGFloat(count - 1) * gap) / CGFloat(count))
        let midY = bounds.midY

        for index in 0..<count {
            let position = CGFloat(index) / CGFloat(max(1, count - 1))
            let envelope = 0.22 + 0.78 * exp(-pow((position - 0.5) / 0.25, 2))
            let variation = 0.28 + 0.72 * abs(sin(Double(index) * 0.67))
            let baseHeight = max(2, bounds.height * CGFloat(envelope * variation) * (active ? 0.62 : 0.24))
            let bar = CALayer()
            bar.bounds = CGRect(x: 0, y: 0, width: barWidth, height: baseHeight)
            bar.position = CGPoint(x: CGFloat(index) * (barWidth + gap) + barWidth / 2, y: midY)
            bar.cornerRadius = barWidth / 2
            bar.backgroundColor = accentColor.withAlphaComponent(0.92).cgColor
            bar.shadowColor = accentColor.cgColor
            bar.shadowRadius = active ? 3 : 0
            bar.shadowOpacity = active ? 0.28 : 0
            root.addSublayer(bar)

            guard !reduceMotion else { continue }
            let animation = CAKeyframeAnimation(keyPath: "transform.scale.y")
            if active {
                animation.values = [0.18, 0.52 + variation * 0.25, 1.15 + variation * 0.75,
                                    0.30 + variation * 0.2, 0.82 + variation * 0.35, 0.18]
            } else {
                // Keep the idle neural waveform alive with a slower, restrained breathing motion.
                animation.values = [0.52, 0.72 + variation * 0.12, 0.92 + variation * 0.16,
                                    0.62, 0.82 + variation * 0.12, 0.52]
            }
            animation.keyTimes = [0, 0.18, 0.38, 0.58, 0.78, 1]
            animation.duration = (active ? 0.78 : 1.65) + Double(index % 9) * (active ? 0.055 : 0.075)
            animation.beginTime = CACurrentMediaTime() + Double((index * 7) % 19) * 0.045
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.isRemovedOnCompletion = false
            bar.add(animation, forKey: "nova-wave-pulse")
        }
    }
}


struct JarvisShoulderArmor: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        return Path { p in
            p.move(to: CGPoint(x: w * 0.04, y: h * 0.92))
            p.addCurve(to: CGPoint(x: w * 0.27, y: h * 0.40),
                       control1: CGPoint(x: w * 0.08, y: h * 0.66),
                       control2: CGPoint(x: w * 0.16, y: h * 0.46))
            p.addLine(to: CGPoint(x: w * 0.40, y: h * 0.31))
            p.addLine(to: CGPoint(x: w * 0.60, y: h * 0.31))
            p.addLine(to: CGPoint(x: w * 0.73, y: h * 0.40))
            p.addCurve(to: CGPoint(x: w * 0.96, y: h * 0.92),
                       control1: CGPoint(x: w * 0.84, y: h * 0.46),
                       control2: CGPoint(x: w * 0.92, y: h * 0.66))
            p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.98))
            p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.98))
            p.closeSubpath()
        }
    }
}