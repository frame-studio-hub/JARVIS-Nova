import SwiftUI

struct SPPlaceholder: View {
    let accent: Color
    var body: some View {
        ZStack {
            LinearGradient(colors: [accent.opacity(0.55), Color(white: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "music.note").font(.system(size: 34, weight: .light)).foregroundStyle(.white.opacity(0.85))
        }
    }
}

struct SPArtwork: View {
    let urlString: String?
    let accent: Color
    var body: some View {
        Group {
            if let s = urlString, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { SPPlaceholder(accent: accent) }
                }
            } else {
                SPPlaceholder(accent: accent)
            }
        }
    }
}

func spTime(_ seconds: Double) -> String {
    let s = Int(Swift.max(0, seconds))
    return String(format: "%d:%02d", s / 60, s % 60)
}

struct SPControls: View {
    let playing: Bool
    let accent: Color
    var compact = false
    let run: (String) -> Void

    private func btn(_ icon: String, _ cmd: String, _ size: CGFloat) -> some View {
        Button { run(cmd) } label: {
            Image(systemName: icon).font(.system(size: size, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
        }.buttonStyle(.plain)
    }

    var body: some View {
        HStack(spacing: compact ? 15 : 22) {
            btn("shuffle", "перемешать Spotify", compact ? 12 : 14)
            btn("backward.end.fill", "предыдущий трек Spotify", compact ? 15 : 18)
            Button { run(playing ? "пауза Spotify" : "продолжи Spotify") } label: {
                ZStack {
                    Circle().fill(LinearGradient(colors: [accent, accent.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                        .frame(width: compact ? 36 : 46, height: compact ? 36 : 46)
                        .shadow(color: accent.opacity(0.75), radius: 9)
                    Circle().stroke(.white.opacity(0.55), lineWidth: 1).frame(width: compact ? 36 : 46, height: compact ? 36 : 46)
                    Image(systemName: playing ? "pause.fill" : "play.fill").font(.system(size: compact ? 14 : 18, weight: .bold)).foregroundStyle(.black)
                }
            }.buttonStyle(.plain)
            btn("forward.end.fill", "следующий трек Spotify", compact ? 15 : 18)
            btn("repeat", "повтор Spotify", compact ? 12 : 14)
        }
    }
}

struct SPProgress: View {
    let elapsed: Double
    let duration: Double
    let accent: Color
    let seek: (Double) -> Void
    @State private var drag: Double?

    var body: some View {
        let shown = drag ?? elapsed
        let frac = duration > 0 ? Swift.min(1, Swift.max(0, shown / duration)) : 0
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18)).frame(height: 5)
                    Capsule().fill(LinearGradient(colors: [accent.opacity(0.5), accent], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(frac), height: 5)
                        .shadow(color: accent.opacity(0.8), radius: 5)
                    Circle().fill(.white).frame(width: 13, height: 13).shadow(color: accent, radius: 5)
                        .offset(x: geo.size.width * CGFloat(frac) - 6.5)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in drag = Double(Swift.min(1, Swift.max(0, v.location.x / Swift.max(geo.size.width, 1)))) * duration }
                    .onEnded { v in
                        let target = Double(Swift.min(1, Swift.max(0, v.location.x / Swift.max(geo.size.width, 1)))) * duration
                        drag = nil
                        if duration > 0 { seek(target) }
                    })
            }.frame(height: 16)
            HStack {
                Text(spTime(shown))
                Spacer()
                Text(duration > 0 ? spTime(duration) : "--:--")
            }.font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.6)).monospacedDigit()
        }
    }
}

struct SPEqualizer: View {
    let accent: Color
    let playing: Bool
    let date: Date
    var body: some View {
        Canvas { context, size in
            let t = date.timeIntervalSinceReferenceDate
            let n = Int(size.width / 6)
            for i in 0..<n {
                let u = Double(i) / Double(Swift.max(n - 1, 1))
                let v = playing ? (abs(sin(u * 14 + t * 3.2)) * 0.6 + abs(sin(u * 5 - t * 2)) * 0.4) : 0.12
                let h = Swift.max(2, CGFloat(v) * size.height)
                let rect = CGRect(x: CGFloat(i) * 6, y: size.height - h, width: 3.4, height: h)
                context.fill(Path(roundedRect: rect, cornerRadius: 1.7),
                             with: .linearGradient(Gradient(colors: [accent, accent.opacity(0.15)]), startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)))
            }
        }
    }
}

struct SPWaveProgress: View {
    let elapsed: Double
    let duration: Double
    let seed: Double
    let accent: Color
    let seek: (Double) -> Void
    @State private var drag: Double?

    var body: some View {
        let shown = drag ?? elapsed
        let frac = duration > 0 ? Swift.min(1, Swift.max(0, shown / duration)) : 0
        GeometryReader { geo in
            Canvas { context, size in
                let n = Int(size.width / 5)
                for i in 0..<n {
                    let fi = Double(i)
                    let h = (0.22 + 0.78 * abs(sin(fi * 0.37 + seed) * cos(fi * 0.11 + seed * 0.5))) * Double(size.height)
                    let rect = CGRect(x: CGFloat(i) * 5, y: (size.height - CGFloat(h)) / 2, width: 2.6, height: CGFloat(h))
                    let played = Double(i) / Double(Swift.max(n, 1)) <= frac
                    if played {
                        context.drawLayer { l in
                            l.addFilter(.shadow(color: accent.opacity(0.8), radius: 3))
                            l.fill(Path(roundedRect: rect, cornerRadius: 1.3), with: .color(accent))
                        }
                    } else {
                        context.fill(Path(roundedRect: rect, cornerRadius: 1.3), with: .color(.white.opacity(0.2)))
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in drag = Double(Swift.min(1, Swift.max(0, v.location.x / Swift.max(geo.size.width, 1)))) * duration }
                .onEnded { v in
                    let target = Double(Swift.min(1, Swift.max(0, v.location.x / Swift.max(geo.size.width, 1)))) * duration
                    drag = nil
                    if duration > 0 { seek(target) }
                })
        }
    }
}

// MARK: - Spotify card variants 1...4

struct SpotifyVariantView: View {
    let variant: Int
    @ObservedObject var player: SpotifyNowPlaying
    let accent: Color
    let run: (String) -> Void
    let seek: (Double) -> Void

    private var playing: Bool { player.track?.state == "playing" }
    private var title: String { player.track?.title ?? "Нет активного трека" }
    private var artist: String { player.track?.artist ?? "Открой Spotify" }
    private var album: String { player.track?.album ?? "" }

    private var header: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(accent).frame(width: 27, height: 27).shadow(color: accent.opacity(0.55), radius: 7)
                Image(systemName: "waveform").font(.system(size: 13, weight: .black)).foregroundStyle(.black)
            }
            Text("Spotify")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.98))
                .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
            Spacer(minLength: 0)
            Text(player.isAdvertisementDetected ? "AD" : (playing ? "NOW PLAYING" : "PAUSED"))
                .font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(accent.opacity(0.14), in: Capsule())
                .overlay(Capsule().stroke(accent.opacity(0.5), lineWidth: 0.8))
                .foregroundStyle(accent)
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let elapsed = player.track?.elapsed(at: tl.date) ?? 0
            let duration = player.track?.durationSeconds ?? 0
            VStack(spacing: 8) {
                header
                Group {
                    switch variant {
                    case 1: vinyl(elapsed, duration)
                    case 2: immersive(tl.date, elapsed, duration)
                    case 3: ring(tl.date, elapsed, duration)
                    default: typographic(elapsed, duration)
                    }
                }.frame(maxHeight: .infinity)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.white)
        }
    }

    // 1 — vinyl record with tonearm
    private func vinyl(_ elapsed: Double, _ duration: Double) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Canvas { context, size in
                    let c = CGPoint(x: size.width * 0.46, y: size.height / 2)
                    let R = Swift.min(size.width * 0.92, size.height) / 2 - 2
                    context.drawLayer { l in
                        l.addFilter(.shadow(color: .black.opacity(0.85), radius: 9, x: 0, y: 6))
                        l.fill(PV.circle(c, R), with: .radialGradient(Gradient(colors: [Color(white: 0.17), Color(white: 0.025)]), center: c, startRadius: 0, endRadius: R))
                    }
                    for i in 0..<28 {
                        context.stroke(PV.circle(c, R * (0.37 + CGFloat(i) * 0.0225)), with: .color(.white.opacity(i % 3 == 0 ? 0.1 : 0.035)), lineWidth: 0.7)
                    }
                    for start in [28.0, 208.0] {
                        var wedge = Path()
                        wedge.move(to: c)
                        wedge.addArc(center: c, radius: R - 1, startAngle: .degrees(start), endAngle: .degrees(start + 30), clockwise: false)
                        wedge.closeSubpath()
                        context.fill(wedge, with: .color(.white.opacity(0.07)))
                    }
                    context.stroke(PV.circle(c, R * 0.34), with: .color(accent.opacity(0.8)), lineWidth: 1.2)
                    let pivot = CGPoint(x: size.width * 0.96, y: size.height * 0.1)
                    let head = playing ? CGPoint(x: c.x + R * 0.5, y: c.y - R * 0.5) : CGPoint(x: c.x + R * 1.0, y: c.y - R * 0.95)
                    var arm = Path()
                    arm.move(to: pivot)
                    arm.addQuadCurve(to: head, control: CGPoint(x: pivot.x - 2, y: (pivot.y + head.y) / 2 + 20))
                    context.drawLayer { l in
                        l.addFilter(.shadow(color: .black.opacity(0.7), radius: 4, x: -2, y: 3))
                        l.stroke(arm, with: .color(Color(white: 0.8)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                        l.fill(PV.circle(pivot, 9), with: .color(Color(white: 0.35)))
                        l.fill(PV.circle(head, 4.5), with: .color(accent))
                    }
                }
                SPArtwork(urlString: player.track?.artworkURL, accent: accent)
                    .frame(width: 92, height: 92).clipShape(Circle())
                    .rotationEffect(.degrees(elapsed * 36))
                    .offset(x: -9)
                Circle().fill(Color.black).frame(width: 12, height: 12).overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1)).offset(x: -9)
            }
            .frame(width: 205).frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 20, weight: .semibold)).lineLimit(2)
                Text(artist).font(.system(size: 14)).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                if !album.isEmpty { Text(album).font(.system(size: 10)).foregroundStyle(.white.opacity(0.45)).lineLimit(1) }
                Spacer(minLength: 0)
                SPProgress(elapsed: elapsed, duration: duration, accent: accent, seek: seek)
                SPControls(playing: playing, accent: accent, compact: true, run: run)
            }
        }
    }

    // 2 — immersive blurred cover
    private func immersive(_ date: Date, _ elapsed: Double, _ duration: Double) -> some View {
        HStack(spacing: 16) {
            VStack(spacing: 3) {
                SPArtwork(urlString: player.track?.artworkURL, accent: accent)
                    .frame(width: 138, height: 138).clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.35), lineWidth: 1))
                    .shadow(color: accent.opacity(0.45), radius: 16, y: 6)
                SPArtwork(urlString: player.track?.artworkURL, accent: accent)
                    .frame(width: 138, height: 138).clipShape(RoundedRectangle(cornerRadius: 14))
                    .scaleEffect(x: 1, y: -1).opacity(0.22)
                    .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
                    .frame(height: 30, alignment: .top).clipped()
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 24, weight: .bold)).lineLimit(2).minimumScaleFactor(0.8)
                Text(artist).font(.system(size: 15)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                Spacer(minLength: 0)
                SPEqualizer(accent: accent, playing: playing, date: date).frame(height: 30)
                SPProgress(elapsed: elapsed, duration: duration, accent: accent, seek: seek)
                SPControls(playing: playing, accent: accent, compact: true, run: run)
            }
        }
        .background(alignment: .center) {
            SPArtwork(urlString: player.track?.artworkURL, accent: accent)
                .scaleEffect(1.35).blur(radius: 30).opacity(0.34)
                .overlay(LinearGradient(colors: [.black.opacity(0.34), .black.opacity(0.68)], startPoint: .top, endPoint: .bottom))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // 3 — progress ring around the cover
    private func ring(_ date: Date, _ elapsed: Double, _ duration: Double) -> some View {
        let frac = duration > 0 ? Swift.min(1, elapsed / duration) : 0
        return HStack(spacing: 18) {
            ZStack {
                Canvas { context, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r = Swift.min(size.width, size.height) / 2 - 6
                    context.stroke(PV.circle(c, r), with: .color(.white.opacity(0.12)), lineWidth: 6)
                    var arc = Path()
                    arc.addArc(center: c, radius: r, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * frac), clockwise: false)
                    context.drawLayer { l in
                        l.addFilter(.shadow(color: accent, radius: 8))
                        l.stroke(arc, with: .color(accent), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    }
                    for i in 0..<60 {
                        let a = Double(i) * Double.pi / 30
                        context.fill(PV.circle(PV.pt(c, a, r - 10), 0.9), with: .color(.white.opacity(0.3)))
                    }
                }
                SPArtwork(urlString: player.track?.artworkURL, accent: accent)
                    .frame(width: 118, height: 118).clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                Button { run(playing ? "пауза Spotify" : "продолжи Spotify") } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 54, height: 54).background(.black.opacity(0.45), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.55), lineWidth: 1))
                }.buttonStyle(.plain)
            }
            .frame(width: 170, height: 170).frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 20, weight: .semibold)).lineLimit(2)
                Text(artist).font(.system(size: 14)).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                Text("\(spTime(elapsed)) / \(duration > 0 ? spTime(duration) : "--:--")")
                    .font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(accent).monospacedDigit()
                Spacer(minLength: 0)
                SPEqualizer(accent: accent, playing: playing, date: date).frame(height: 38)
                SPControls(playing: playing, accent: accent, compact: true, run: run)
            }
        }
    }

    // 4 — typographic with waveform scrubber
    private func typographic(_ elapsed: Double, _ duration: Double) -> some View {
        let seed = Double(title.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } % 97)
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 32, weight: .heavy, design: .rounded)).lineLimit(2).minimumScaleFactor(0.6)
                .foregroundStyle(LinearGradient(colors: [.white, accent], startPoint: .leading, endPoint: .trailing))
                .shadow(color: accent.opacity(0.4), radius: 10)
            HStack(spacing: 8) {
                Text(artist).font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                if !album.isEmpty {
                    Text("•").foregroundStyle(accent)
                    Text(album).font(.system(size: 12)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            SPWaveProgress(elapsed: elapsed, duration: duration, seed: seed, accent: accent, seek: seek).frame(height: 54)
            HStack {
                Text(spTime(elapsed))
                Spacer()
                Text(duration > 0 ? spTime(duration) : "--:--")
            }.font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.6)).monospacedDigit()
            HStack { Spacer(); SPControls(playing: playing, accent: accent, compact: true, run: run); Spacer() }
        }
    }
}