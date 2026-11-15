import SwiftUI

enum PV {
    static let lime = Color(red: 0.92, green: 1.0, blue: 0.35)

    static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    static func pt(_ c: CGPoint, _ a: Double, _ r: CGFloat) -> CGPoint {
        CGPoint(x: c.x + CGFloat(sin(a)) * r, y: c.y - CGFloat(cos(a)) * r)
    }

    static func text(_ date: Date, _ pattern: String, zone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = zone
        f.dateFormat = pattern
        return f.string(from: date)
    }

    static func capitalized(_ s: String) -> String {
        s.prefix(1).uppercased() + s.dropFirst()
    }

    static func clockParts(_ date: Date) -> (s: Double, m: Double, h: Double) {
        let cp = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let s = Double(cp.second ?? 0) + Double(cp.nanosecond ?? 0) / 1_000_000_000
        let m = Double(cp.minute ?? 0) + s / 60
        let h = Double((cp.hour ?? 0) % 12) + m / 60
        return (s, m, h)
    }
}

// MARK: - Clock card (5 variants)

struct ClockCardContent: View {
    let variant: Int
    let accent: Color

    var body: some View {
        Group {
            switch variant {
            case 1: NeonRingsClock(accent: accent)
            case 2: DigitalWorldClock(accent: accent)
            case 3: OrbitalClock(accent: accent)
            case 4: FlipClock(accent: accent)
            default: MetalClockContent(accent: accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MetalClockContent: View {
    let accent: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            HStack(spacing: 12) {
                AnalogClockFace(date: tl.date, accent: accent)
                    .frame(width: 204, height: 204)
                    .frame(maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(PV.text(tl.date, "HH:mm"))
                            .font(.system(size: 40, weight: .light, design: .rounded)).monospacedDigit().fixedSize()
                        Text(PV.text(tl.date, "ss"))
                            .font(.system(size: 16, weight: .medium, design: .rounded)).monospacedDigit().foregroundStyle(accent).fixedSize()
                    }
                    Rectangle().fill(LinearGradient(colors: [accent, .clear], startPoint: .leading, endPoint: .trailing)).frame(height: 1.5)
                    Text(PV.text(tl.date, "d MMMM")).font(.system(size: 16, weight: .medium)).foregroundStyle(.white.opacity(0.92)).fixedSize()
                    Text(PV.capitalized(PV.text(tl.date, "EEEE"))).font(.system(size: 14)).foregroundStyle(.white.opacity(0.65)).fixedSize()
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct NeonRingsClock: View {
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 24)) { tl in
                    Canvas { context, size in
                        let p = PV.clockParts(tl.date)
                        let c = CGPoint(x: size.width / 2, y: size.height / 2)
                        let R = Swift.min(size.width, size.height) / 2 - 4
                        let rings: [(CGFloat, Double, Color)] = [(0.96, p.s / 60, accent), (0.80, p.m / 60, PV.lime), (0.64, p.h / 12, Color.white)]
                        for ring in rings {
                            let r = R * ring.0
                            context.stroke(PV.circle(c, r), with: .color(.white.opacity(0.08)), lineWidth: 9)
                            var arc = Path()
                            arc.addArc(center: c, radius: r, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * ring.1), clockwise: false)
                            context.drawLayer { l in
                                l.addFilter(.shadow(color: ring.2, radius: 7))
                                l.stroke(arc, with: .color(ring.2), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            }
                            let tip = PV.pt(c, ring.1 * 2 * Double.pi, r)
                            context.fill(PV.circle(tip, 3.2), with: .color(.white))
                        }
                        for i in 0..<60 {
                            let a = Double(i) * Double.pi / 30
                            let lit = Double(i) <= p.s
                            let dotColor: Color = lit ? accent : Color.white.opacity(0.22)
                            context.fill(PV.circle(PV.pt(c, a, R * 0.47), lit ? 1.8 : 1.1), with: .color(dotColor))
                        }
                    }
                }
                TimelineView(.periodic(from: .now, by: 1)) { tl in
                    VStack(spacing: 0) {
                        Text(PV.text(tl.date, "HH:mm")).font(.system(size: 31, weight: .light, design: .rounded)).monospacedDigit().fixedSize()
                        Text(PV.text(tl.date, "ss")).font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(accent)
                    }
                }
            }
            .frame(width: 210, height: 210)
            TimelineView(.periodic(from: .now, by: 1)) { tl in
                let cal = Calendar.current
                let day = cal.ordinality(of: .day, in: .year, for: tl.date) ?? 1
                let week = cal.component(.weekOfYear, from: tl.date)
                VStack(alignment: .leading, spacing: 5) {
                    Text(PV.text(tl.date, "EEEE").uppercased()).font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(accent).fixedSize()
                    Text(PV.text(tl.date, "dd")).font(.system(size: 46, weight: .thin, design: .rounded)).monospacedDigit().fixedSize()
                    Text(PV.capitalized(PV.text(tl.date, "LLLL yyyy"))).font(.system(size: 12)).foregroundStyle(.white.opacity(0.7)).fixedSize()
                    Spacer().frame(height: 4)
                    Text("Неделя \(week)  •  День \(day)").font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.55)).fixedSize()
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.12))
                            Capsule().fill(LinearGradient(colors: [accent.opacity(0.5), accent], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * CGFloat(day) / 365)
                                .shadow(color: accent.opacity(0.8), radius: 4)
                        }
                    }.frame(width: 100, height: 4)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct DigitalWorldClock: View {
    let accent: Color
    private let zones: [(String, String)] = [("Лондон", "Europe/London"), ("Нью-Йорк", "America/New_York"), ("Токио", "Asia/Tokyo"), ("Москва", "Europe/Moscow")]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            let secs = Calendar.current.component(.second, from: tl.date)
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(PV.text(tl.date, "HH:mm"))
                        .font(.system(size: 66, weight: .ultraLight, design: .rounded)).monospacedDigit().fixedSize()
                        .foregroundStyle(LinearGradient(colors: [.white, Color(white: 0.7)], startPoint: .top, endPoint: .bottom))
                        .shadow(color: accent.opacity(0.55), radius: 14)
                    Text(PV.text(tl.date, "ss"))
                        .font(.system(size: 24, weight: .light, design: .rounded)).monospacedDigit().foregroundStyle(accent).fixedSize()
                        .shadow(color: accent, radius: 8)
                }
                HStack(spacing: 2.2) {
                    ForEach(0..<60, id: \.self) { i in
                        Capsule()
                            .fill(i <= secs ? accent : Color.white.opacity(0.14))
                            .frame(height: i % 5 == 0 ? 9 : 6)
                            .shadow(color: i <= secs ? accent.opacity(0.7) : .clear, radius: 2)
                    }
                }.frame(height: 10)
                Text(PV.capitalized(PV.text(tl.date, "EEEE, d MMMM yyyy")))
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.75))
                Spacer(minLength: 2)
                HStack(spacing: 0) {
                    ForEach(Array(zones.enumerated()), id: \.offset) { index, zone in
                        let tz = TimeZone(identifier: zone.1) ?? .current
                        let hour = Calendar.current.dateComponents(in: tz, from: tl.date).hour ?? 12
                        VStack(spacing: 3) {
                            Image(systemName: (hour >= 6 && hour < 20) ? "sun.max.fill" : "moon.stars.fill")
                                .font(.system(size: 13)).foregroundStyle((hour >= 6 && hour < 20) ? Color.yellow : accent)
                            Text(PV.text(tl.date, "HH:mm", zone: tz)).font(.system(size: 14, weight: .medium, design: .rounded)).monospacedDigit()
                            Text(zone.0).font(.system(size: 9)).foregroundStyle(.white.opacity(0.55))
                        }.frame(maxWidth: .infinity)
                        if index < zones.count - 1 { Rectangle().fill(.white.opacity(0.14)).frame(width: 1, height: 38) }
                    }
                }
                .padding(.vertical, 8)
                .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12), lineWidth: 0.8))
            }
        }
    }
}

struct OrbitalClock: View {
    let accent: Color

    var body: some View {
        ZStack(alignment: .bottom) {
            TimelineView(.animation(minimumInterval: 1.0 / 24)) { tl in
                Canvas { context, size in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let p = PV.clockParts(tl.date)
                    let c = CGPoint(x: size.width * 0.5, y: size.height * 0.44)
                    let W = size.width
                    for i in 0..<48 {
                        let fi = Double(i)
                        let rx = abs(sin(fi * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
                        let ry = abs(sin(fi * 78.233) * 43758.5453).truncatingRemainder(dividingBy: 1)
                        let tw = 0.25 + 0.75 * abs(sin(t * 0.9 + fi))
                        let star = PV.circle(CGPoint(x: size.width * CGFloat(rx), y: size.height * CGFloat(ry)), CGFloat(0.5 + rx))
                        context.fill(star, with: .color(.white.opacity(tw * 0.55)))
                    }
                    let orbits: [(CGFloat, CGFloat, Double, CGFloat, Color)] = [
                        (W * 0.46, W * 0.15, p.s / 60, 5.0, accent),
                        (W * 0.34, W * 0.11, p.m / 60, 6.5, PV.lime),
                        (W * 0.22, W * 0.07, p.h / 12, 8.0, Color.white)
                    ]
                    for o in orbits {
                        let rect = CGRect(x: c.x - o.0, y: c.y - o.1, width: o.0 * 2, height: o.1 * 2)
                        context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.14)), style: StrokeStyle(lineWidth: 0.8, dash: [3, 4]))
                    }
                    func place(_ o: (CGFloat, CGFloat, Double, CGFloat, Color), _ a: Double) -> CGPoint {
                        CGPoint(x: c.x + o.0 * CGFloat(sin(a)), y: c.y - o.1 * CGFloat(cos(a)))
                    }
                    for pass in 0..<2 {
                        if pass == 1 {
                            context.drawLayer { l in
                                l.addFilter(.shadow(color: accent, radius: 16))
                                l.fill(PV.circle(c, W * 0.085), with: .radialGradient(Gradient(colors: [.white, accent, accent.opacity(0.25)]),
                                                                                    center: CGPoint(x: c.x - 4, y: c.y - 4), startRadius: 0, endRadius: W * 0.1))
                            }
                        }
                        for o in orbits {
                            let a = o.2 * 2 * Double.pi
                            let pos = place(o, a)
                            let front = pos.y > c.y
                            if (pass == 1) != front { continue }
                            let depth = 1 + 0.35 * (pos.y - c.y) / o.1
                            for k in 1...14 {
                                let tp = place(o, a - Double(k) * 0.05)
                                let fade = 1 - Double(k) / 15
                                context.fill(PV.circle(tp, o.3 * depth * CGFloat(fade) * 0.8), with: .color(o.4.opacity(fade * 0.45)))
                            }
                            context.drawLayer { l in
                                l.addFilter(.shadow(color: o.4, radius: 8))
                                l.fill(PV.circle(pos, o.3 * depth), with: .radialGradient(Gradient(colors: [.white, o.4]),
                                                                                           center: CGPoint(x: pos.x - 1.5, y: pos.y - 1.5), startRadius: 0, endRadius: o.3 * depth))
                            }
                        }
                    }
                }
            }
            TimelineView(.periodic(from: .now, by: 1)) { tl in
                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(PV.text(tl.date, "HH:mm")).font(.system(size: 34, weight: .light, design: .rounded)).monospacedDigit().fixedSize()
                        Text(PV.text(tl.date, "ss")).font(.system(size: 14, weight: .medium, design: .rounded)).monospacedDigit().foregroundStyle(accent).fixedSize()
                    }
                    Text(PV.capitalized(PV.text(tl.date, "EEEE, d MMMM"))).font(.system(size: 11)).foregroundStyle(.white.opacity(0.65)).fixedSize()
                }.padding(.bottom, 2)
            }
        }
    }
}

struct FlipCard: View {
    let value: String
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [Color(white: 0.22), Color(white: 0.05)], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.04), .white.opacity(0.2)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            Text(value)
                .font(.system(size: 72, weight: .bold, design: .rounded)).monospacedDigit().fixedSize()
                .foregroundStyle(LinearGradient(colors: [.white, Color(white: 0.7)], startPoint: .top, endPoint: .bottom))
            Rectangle().fill(.black.opacity(0.8)).frame(height: 3)
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1).offset(y: 2)
            HStack {
                Circle().fill(Color(white: 0.4)).frame(width: 6, height: 6)
                Spacer()
                Circle().fill(Color(white: 0.4)).frame(width: 6, height: 6)
            }.padding(.horizontal, 6)
        }
        .frame(width: 118, height: 134)
        .shadow(color: .black.opacity(0.65), radius: 9, y: 7)
        .shadow(color: accent.opacity(0.12), radius: 12)
    }
}

struct FlipClock: View {
    let accent: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            let secs = Calendar.current.component(.second, from: tl.date)
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    FlipCard(value: PV.text(tl.date, "HH"), accent: accent)
                    VStack(spacing: 14) {
                        Circle().fill(accent).frame(width: 7, height: 7).shadow(color: accent, radius: 5)
                        Circle().fill(accent).frame(width: 7, height: 7).shadow(color: accent, radius: 5)
                    }.opacity(secs % 2 == 0 ? 1 : 0.25)
                    FlipCard(value: PV.text(tl.date, "mm"), accent: accent)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.1))
                        Capsule().fill(LinearGradient(colors: [accent.opacity(0.4), accent], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(secs + 1) / 60)
                            .shadow(color: accent, radius: 4)
                    }
                }.frame(width: 270, height: 4)
                Text(PV.capitalized(PV.text(tl.date, "EEEE, d MMMM")))
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}