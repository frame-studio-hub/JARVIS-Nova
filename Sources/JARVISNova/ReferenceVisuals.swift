import SwiftUI

struct ReferenceAtmosphere: View {
    let accent: Color
    let reducedMotion: Bool
    let wallpaper: NSImage?

    var body: some View {
        GeometryReader { geo in
            Group {
                if let wallpaper {
                    Image(nsImage: wallpaper)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Color.black
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(LinearGradient(colors: [.black.opacity(0.18), .black.opacity(0.42)], startPoint: .top, endPoint: .bottom))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct ReferenceWaveform: View {
    let accent: Color
    let compact: Bool
    var body: some View {
        Canvas { context, size in
            let count = compact ? 42 : 76
            let mid = size.height / 2
            for i in 0..<count {
                let x = CGFloat(i) / CGFloat(max(1, count - 1)) * size.width
                let center = Double(count) * 0.5
                let envelope = compact ? 0.42 : (0.16 + 0.84 * exp(-pow((Double(i) - center) / (Double(count) * 0.24), 2)))
                let pulse = 0.25 + 0.75 * abs(sin(Double(i) * 0.72))
                let h = CGFloat((3 + pulse * (compact ? 15 : 42)) * envelope)
                let bar = Path(roundedRect: CGRect(x: x, y: mid - h / 2, width: max(1.5, size.width / CGFloat(count) * 0.48), height: h), cornerRadius: 2)
                context.fill(bar, with: .color(accent.opacity(0.88)))
            }
            var baseline = Path()
            baseline.move(to: CGPoint(x: 0, y: mid))
            baseline.addLine(to: CGPoint(x: size.width, y: mid))
            context.stroke(baseline, with: .color(accent.opacity(0.18)), lineWidth: 1)
        }
    }
}

struct JarvisHelmetMark: View {
    let accent: Color
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Ellipse().fill(accent.opacity(0.20)).frame(width: w * 0.76, height: h * 0.28).blur(radius: 24).offset(y: h * 0.32)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.50, y: h * 0.025))
                    p.addCurve(to: CGPoint(x: w * 0.16, y: h * 0.22), control1: CGPoint(x: w * 0.28, y: h * 0.02), control2: CGPoint(x: w * 0.17, y: h * 0.08))
                    p.addLine(to: CGPoint(x: w * 0.08, y: h * 0.62))
                    p.addCurve(to: CGPoint(x: w * 0.27, y: h * 0.91), control1: CGPoint(x: w * 0.07, y: h * 0.80), control2: CGPoint(x: w * 0.16, y: h * 0.89))
                    p.addLine(to: CGPoint(x: w * 0.39, y: h * 0.98))
                    p.addLine(to: CGPoint(x: w * 0.61, y: h * 0.98))
                    p.addLine(to: CGPoint(x: w * 0.73, y: h * 0.91))
                    p.addCurve(to: CGPoint(x: w * 0.92, y: h * 0.62), control1: CGPoint(x: w * 0.84, y: h * 0.89), control2: CGPoint(x: w * 0.93, y: h * 0.80))
                    p.addLine(to: CGPoint(x: w * 0.84, y: h * 0.22))
                    p.addCurve(to: CGPoint(x: w * 0.50, y: h * 0.025), control1: CGPoint(x: w * 0.83, y: h * 0.08), control2: CGPoint(x: w * 0.72, y: h * 0.02))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Color(white: 0.42), Color(white: 0.055), Color(white: 0.20), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    Path { p in
                        p.move(to: CGPoint(x: w * 0.50, y: h * 0.025))
                        p.addCurve(to: CGPoint(x: w * 0.16, y: h * 0.22), control1: CGPoint(x: w * 0.28, y: h * 0.02), control2: CGPoint(x: w * 0.17, y: h * 0.08))
                        p.addLine(to: CGPoint(x: w * 0.08, y: h * 0.62))
                        p.addCurve(to: CGPoint(x: w * 0.27, y: h * 0.91), control1: CGPoint(x: w * 0.07, y: h * 0.80), control2: CGPoint(x: w * 0.16, y: h * 0.89))
                        p.addLine(to: CGPoint(x: w * 0.39, y: h * 0.98))
                        p.addLine(to: CGPoint(x: w * 0.61, y: h * 0.98))
                        p.addLine(to: CGPoint(x: w * 0.73, y: h * 0.91))
                        p.addCurve(to: CGPoint(x: w * 0.92, y: h * 0.62), control1: CGPoint(x: w * 0.84, y: h * 0.89), control2: CGPoint(x: w * 0.93, y: h * 0.80))
                        p.addLine(to: CGPoint(x: w * 0.84, y: h * 0.22))
                        p.addCurve(to: CGPoint(x: w * 0.50, y: h * 0.025), control1: CGPoint(x: w * 0.83, y: h * 0.08), control2: CGPoint(x: w * 0.72, y: h * 0.02))
                    }.stroke(.white.opacity(0.48), lineWidth: 1.4)
                }
                Path { p in
                    p.move(to: CGPoint(x: w * 0.5, y: h * 0.08))
                    p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.42))
                    p.move(to: CGPoint(x: w * 0.22, y: h * 0.24))
                    p.addLine(to: CGPoint(x: w * 0.34, y: h * 0.39))
                    p.move(to: CGPoint(x: w * 0.78, y: h * 0.24))
                    p.addLine(to: CGPoint(x: w * 0.66, y: h * 0.39))
                    p.move(to: CGPoint(x: w * 0.22, y: h * 0.68))
                    p.addLine(to: CGPoint(x: w * 0.36, y: h * 0.84))
                    p.move(to: CGPoint(x: w * 0.78, y: h * 0.68))
                    p.addLine(to: CGPoint(x: w * 0.64, y: h * 0.84))
                }.stroke(accent.opacity(0.48), lineWidth: 1.2)
                // Layered forehead armor, cheek plates and illuminated side vents.
                Path { p in
                    p.move(to: CGPoint(x: w * 0.28, y: h * 0.17))
                    p.addLine(to: CGPoint(x: w * 0.43, y: h * 0.13))
                    p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.15))
                    p.addLine(to: CGPoint(x: w * 0.57, y: h * 0.13))
                    p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.17))
                    p.move(to: CGPoint(x: w * 0.18, y: h * 0.47))
                    p.addLine(to: CGPoint(x: w * 0.31, y: h * 0.53))
                    p.addLine(to: CGPoint(x: w * 0.27, y: h * 0.66))
                    p.move(to: CGPoint(x: w * 0.82, y: h * 0.47))
                    p.addLine(to: CGPoint(x: w * 0.69, y: h * 0.53))
                    p.addLine(to: CGPoint(x: w * 0.73, y: h * 0.66))
                    p.move(to: CGPoint(x: w * 0.34, y: h * 0.88))
                    p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.92))
                    p.addLine(to: CGPoint(x: w * 0.66, y: h * 0.88))
                }.stroke(.white.opacity(0.22), style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round))

                HStack(spacing: w * 0.58) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule().fill(accent.opacity(0.78)).frame(width: 2, height: h * 0.055)
                    }
                }.rotationEffect(.degrees(8)).offset(y: h * 0.17)

                HStack(spacing: w * 0.08) {
                    Capsule().fill(accent).frame(width: w * 0.25, height: h * 0.055).rotationEffect(.degrees(13))
                        .shadow(color: accent, radius: 10)
                    Capsule().fill(accent).frame(width: w * 0.25, height: h * 0.055).rotationEffect(.degrees(-13))
                        .shadow(color: accent, radius: 10)
                }.offset(y: -h * 0.015)
                RoundedRectangle(cornerRadius: 3).fill(.black.opacity(0.85))
                    .frame(width: w * 0.23, height: h * 0.18).overlay(RoundedRectangle(cornerRadius: 3).stroke(accent.opacity(0.7), lineWidth: 1))
                    .offset(y: h * 0.29)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.34, y: h * 0.76))
                    p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.82))
                    p.addLine(to: CGPoint(x: w * 0.66, y: h * 0.76))
                }.stroke(accent.opacity(0.7), lineWidth: 1.5)
            }
            .frame(width: w, height: h)
        }
        .accessibilityLabel("JARVIS metallic helmet")
    }
}

/// Angular, cut-corner frame used by the JARVIS HUD panels.
struct HUDPanelShape: Shape {
    var cut: CGFloat = 16
    func path(in rect: CGRect) -> Path {
        let c = min(cut, min(rect.width, rect.height) * 0.18)
        return Path { p in
            p.move(to: CGPoint(x: rect.minX + c, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - c * 0.72, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c * 0.72))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
            p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX + c * 0.72, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c * 0.72))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + c))
            p.closeSubpath()
        }
    }
}


/// Real photographic artwork behind the live SwiftUI dashboard modules.
/// The image is deliberately the visual source; no procedural 3D ornaments are drawn here.
struct DashboardModuleBackdrop: View {
    let kind: String
    let accent: Color
    var variant: Int = 0
    var condition: String = "cloud.fill"

    private var imageName: String {
        let choices: [String]
        switch kind {
        case "clock": choices = ["JARVIS-ClockNight", "JARVIS-ClockTower", "JARVIS-ClockMetal", "JARVIS-StatsSteel", "JARVIS-Architecture"]
        case "weather":
            let parts = condition.split(separator: ":")
            let code = Int(parts.first ?? "3") ?? 3
            let isDay = parts.count > 1 ? parts[1] == "1" : false
            // Weather artwork is selected only from the live Open-Meteo code and day/night
            // flag. Never let the decorative image pager override the actual conditions.
            if [95, 96, 99].contains(code) {
                choices = ["JARVIS-WeatherCloud"]
            } else if [71, 73, 75, 77, 85, 86].contains(code) {
                choices = ["JARVIS-WeatherMoon"]
            } else if [45, 48].contains(code) {
                choices = ["JARVIS-WeatherCloud"]
            } else if [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].contains(code) {
                choices = ["JARVIS-WeatherCloud"]
            } else if !isDay {
                choices = ["JARVIS-WeatherMoon"]
            } else {
                choices = ["JARVIS-WeatherSkyline"]
            }
        case "stats": choices = ["JARVIS-StatsCity", "JARVIS-StatsCore", "JARVIS-StatsSteel", "JARVIS-ClockMetal", "JARVIS-Architecture"]
        case "voice": choices = ["JARVIS-VoiceWaves", "JARVIS-VoiceCore", "JARVIS-VoiceHelmet", "JARVIS-Android", "JARVIS-Atmosphere"]
        case "music": choices = ["JARVIS-MusicMountain", "JARVIS-MusicNight", "JARVIS-MusicCore", "JARVIS-ClockNight", "JARVIS-StatsCity"]
        default: choices = ["JARVIS-Atmosphere"]
        }
        return choices[((variant % choices.count) + choices.count) % choices.count]
    }

    private var imageAlignment: Alignment {
        switch kind {
        case "clock": return .leading
        case "weather": return .center
        case "stats": return .trailing
        case "music": return .bottomTrailing
        default: return .center
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(imageName, bundle: .module)
                    .resizable()
                    .scaleEffect(x: variant >= 3 ? -1 : 1, y: 1)
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height, alignment: imageAlignment)
                    .clipped()
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(kind == "voice" ? 0.40 : 0.48), location: 0),
                        .init(color: .black.opacity(kind == "weather" ? 0.30 : 0.52), location: 0.52),
                        .init(color: .black.opacity(0.72), location: 1)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing
                )
                if kind == "weather" {
                    let code = Int(condition.split(separator: ":").first ?? "3") ?? 3
                    let atmosphere: Color = [95, 96, 99].contains(code) ? .indigo : ([71, 73, 75, 77, 85, 86].contains(code) ? .cyan : ([45, 48].contains(code) ? .gray : accent))
                    LinearGradient(colors: [atmosphere.opacity(0.18), .clear, accent.opacity(0.08)],
                                   startPoint: .topTrailing, endPoint: .bottomLeading)
                } else if kind == "music" {
                    LinearGradient(colors: [Color.green.opacity(0.12), .clear, .black.opacity(0.22)],
                                   startPoint: .topTrailing, endPoint: .bottomLeading)
                } else {
                    LinearGradient(colors: [accent.opacity(0.08), .clear],
                                   startPoint: .topTrailing, endPoint: .bottomLeading)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .animation(.easeInOut(duration: 1.15), value: condition)
            .allowsHitTesting(false)
        }
    }
}

struct LiveVoiceWaves: View {
    let accent: Color
    let active: Bool
    let reducedMotion: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: reducedMotion ? 1 : 1.0/30, paused: reducedMotion)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for layer in 0..<9 {
                    var path = Path()
                    for i in 0..<240 {
                        let x = CGFloat(i)/239*size.width
                        let t = Double(i)/239
                        let envelope = 0.25 + 0.75*pow(sin(t * .pi), 0.7)
                        let energy = active ? 1.0 : 0.36
                        let phase = reducedMotion ? 0 : time * (active ? 3.0 : 0.55)
                        let wave = sin(t*17 + phase + Double(layer)*0.23) * 0.60 + sin(t*31 - phase*0.7 + Double(layer)*0.4)*0.22
                        let y = size.height*0.5 + CGFloat(wave*envelope*energy)*size.height*(0.23+Double(layer)*0.025)
                        if i == 0 { path.move(to:CGPoint(x:x,y:y)) } else { path.addLine(to:CGPoint(x:x,y:y)) }
                    }
                    context.stroke(path,with:.color(accent.opacity(0.12+Double(layer)*0.055)),lineWidth:layer == 4 ? 2.2 : 1)
                }
                if active {
                    for i in 0..<52 {
                        let x = CGFloat(i)/51*size.width
                        let t = Double(i)/51
                        let pulse = abs(sin(t*19 + (reducedMotion ? 0 : time*4)))
                        let height = CGFloat(5 + pulse*size.height*0.34)
                        let rect=CGRect(x:x,y:size.height/2-height/2,width:2.2,height:height)
                        context.fill(Path(roundedRect:rect,cornerRadius:1),with:.color(accent.opacity(0.35+pulse*0.55)))
                    }
                }
            }
        }
        .accessibilityLabel(active ? "Голосовая волна активна" : "Голосовая волна в режиме ожидания")
    }
}

struct ScrollWheelPageControl: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> WheelCaptureView {
        let view = WheelCaptureView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: WheelCaptureView, context: Context) {
        nsView.onScroll = onScroll
    }

    final class WheelCaptureView: NSView {
        var onScroll: ((CGFloat) -> Void)?
        private var monitor: Any?
        private var accumulatedDelta: CGFloat = 0
        private var lastPageChange = Date.distantPast

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let window = self.window, event.window === window else { return event }
                let point = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.insetBy(dx: -8, dy: -8).contains(point) else { return event }
                let delta = event.scrollingDeltaY
                guard abs(delta) > 0.15 else { return event }
                self.accumulatedDelta += delta
                let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 1.8 : 0.25
                let now = Date()
                guard abs(self.accumulatedDelta) >= threshold,
                      now.timeIntervalSince(self.lastPageChange) > 0.11 else { return event }
                let direction: CGFloat = self.accumulatedDelta > 0 ? 1 : -1
                self.accumulatedDelta = 0
                self.lastPageChange = now
                DispatchQueue.main.async { self.onScroll?(direction) }
                return event
            }
        }

    }
}