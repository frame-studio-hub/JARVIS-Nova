import Foundation
import Combine
import SwiftUI

@MainActor
final class SystemMonitor: ObservableObject {
    struct Sample: Identifiable {
        let id = UUID()
        let date: Date
        let cpu: Double
        let memory: Double
    }

    @Published private(set) var cpuPercent: Double = 0
    @Published private(set) var memoryPercent: Double = 0
    @Published private(set) var memoryUsedGB: Double = 0
    @Published private(set) var memoryTotalGB: Double = 0
    @Published private(set) var diskPercent: Double = 0
    @Published private(set) var diskFreeGB: Double = 0
    @Published private(set) var networkDownBytesPerSecond: Double = 0
    @Published private(set) var networkUpBytesPerSecond: Double = 0
    @Published private(set) var samples: [Sample] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var errorMessage: String?

    private var timer: Timer?
    private var previousNetwork: (rx: Double, tx: Double, date: Date)?

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        Task.detached(priority: .utility) { [weak self] in
            let script = #"""
            cpu=$(top -l 2 -n 0 | awk '/CPU usage/ {gsub(/%/,""); user=$3; sys=$5} END {printf "%.1f", user+sys}')
            mem=$(vm_stat | awk '
              /page size of/ {gsub(/[^0-9]/,"",$8); page=$8}
              /Pages active/ {gsub(/[^0-9]/,"",$3); active=$3}
              /Pages inactive/ {gsub(/[^0-9]/,"",$3); inactive=$3}
              /Pages wired down/ {gsub(/[^0-9]/,"",$4); wired=$4}
              /Pages occupied by compressor/ {gsub(/[^0-9]/,"",$5); compressed=$5}
              END {printf "%.0f %.0f", (active+inactive+wired+compressed)*page/1073741824, page}')
            total=$(sysctl -n hw.memsize)
            totalgb=$(awk -v n="$total" 'BEGIN {printf "%.2f", n/1073741824}')
            usedgb=$(echo "$mem" | awk '{printf "%.2f", $1}')
            ram=$(awk -v u="$usedgb" -v t="$totalgb" 'BEGIN {if(t>0) printf "%.1f",u/t*100; else print 0}')
            disk=$(df -k / | awk 'NR==2 {gsub(/%/,"",$5); printf "%s %.2f", $5, $4/1048576}')
            net=$(netstat -ibn | awk '$1 ~ /^en[0-9]+$/ {rx += $7; tx += $10} END {printf "%.0f %.0f",rx,tx}')
            printf "%s|%s|%s|%s|%s\n" "$cpu" "$ram" "$usedgb" "$totalgb" "$disk $net"
            """#
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", script]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                guard process.terminationStatus == 0,
                      let output = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) else {
                    await self?.setError("Не удалось получить системные показатели")
                    return
                }
                await self?.apply(output)
            } catch {
                await self?.setError(error.localizedDescription)
            }
        }
    }

    private func apply(_ output: String) {
        let fields = output.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 5 else {
            errorMessage = "Системный монитор вернул неполные данные"
            return
        }
        let cpu = Double(fields[0]) ?? 0
        let ram = Double(fields[1]) ?? 0
        let used = Double(fields[2]) ?? 0
        let total = Double(fields[3]) ?? 0
        let extras = fields[4].split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
        guard extras.count >= 4 else {
            errorMessage = "Не удалось разобрать данные накопителя и сети"
            return
        }
        let rx = extras[2]
        let tx = extras[3]
        let now = Date()
        if let previousNetwork {
            let elapsed = max(0.1, now.timeIntervalSince(previousNetwork.date))
            networkDownBytesPerSecond = max(0, (rx - previousNetwork.rx) / elapsed)
            networkUpBytesPerSecond = max(0, (tx - previousNetwork.tx) / elapsed)
        }
        previousNetwork = (rx, tx, now)
        cpuPercent = min(100, max(0, cpu))
        memoryPercent = min(100, max(0, ram))
        memoryUsedGB = used
        memoryTotalGB = total
        diskPercent = min(100, max(0, extras[0]))
        diskFreeGB = extras[1]
        samples.append(Sample(date: now, cpu: cpuPercent, memory: memoryPercent))
        if samples.count > 48 { samples.removeFirst(samples.count - 48) }
        lastUpdated = now
        errorMessage = nil
    }

    private func setError(_ message: String) {
        errorMessage = message
    }

    var networkDownLabel: String { Self.rate(networkDownBytesPerSecond) }
    var networkUpLabel: String { Self.rate(networkUpBytesPerSecond) }

    private static func rate(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1f MB/s", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.0f KB/s", value / 1_000) }
        return String(format: "%.0f B/s", value)
    }
}


struct SystemMetricChart: View {
    let samples: [SystemMonitor.Sample]
    let accent: Color

    var body: some View {
        Canvas { context, size in
            let left: CGFloat = 26
            let plot = CGRect(x: left, y: 4, width: size.width - left - 4, height: size.height - 8)
            for (index, label) in ["100", "75", "50", "25", "0"].enumerated() {
                let y = plot.minY + plot.height * CGFloat(index) / 4
                var grid = Path()
                grid.move(to: CGPoint(x: plot.minX, y: y))
                grid.addLine(to: CGPoint(x: plot.maxX, y: y))
                context.stroke(grid, with: .color(.white.opacity(0.1)), style: StrokeStyle(lineWidth: 0.6, dash: [2, 3]))
                context.draw(Text("\(label)%").font(.system(size: 7, design: .monospaced)).foregroundColor(.white.opacity(0.5)),
                             at: CGPoint(x: left - 4, y: y), anchor: .trailing)
            }
            guard samples.count > 1 else { return }
            for (keyPath, color, fillOpacity) in [
                (\SystemMonitor.Sample.memory, Color(red: 0.92, green: 1.0, blue: 0.35), 0.16),
                (\SystemMonitor.Sample.cpu, accent, 0.34)
            ] {
                let values = samples.map { Swift.min(100, Swift.max(0, $0[keyPath: keyPath])) }
                var points: [CGPoint] = []
                for (index, value) in values.enumerated() {
                    points.append(CGPoint(x: plot.minX + CGFloat(index) / CGFloat(values.count - 1) * plot.width,
                                          y: plot.maxY - CGFloat(value / 100) * plot.height))
                }
                var line = Path()
                for (index, p) in points.enumerated() {
                    if index == 0 { line.move(to: p) } else {
                        let prev = points[index - 1]
                        let mid = CGPoint(x: (prev.x + p.x) / 2, y: (prev.y + p.y) / 2)
                        line.addQuadCurve(to: mid, control: prev)
                        if index == points.count - 1 { line.addLine(to: p) }
                    }
                }
                var area = line
                area.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
                area.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
                area.closeSubpath()
                context.fill(area, with: .linearGradient(Gradient(colors: [color.opacity(fillOpacity), color.opacity(0)]),
                                                         startPoint: CGPoint(x: 0, y: plot.minY), endPoint: CGPoint(x: 0, y: plot.maxY)))
                context.drawLayer { l in
                    l.addFilter(.shadow(color: color, radius: 6))
                    l.stroke(line, with: .color(color), lineWidth: 2)
                }
                if let last = points.last {
                    context.fill(Path(ellipseIn: CGRect(x: last.x - 3, y: last.y - 3, width: 6, height: 6)), with: .color(.white))
                }
            }
        }
        .accessibilityLabel("График реальной загрузки процессора и памяти")
    }
}