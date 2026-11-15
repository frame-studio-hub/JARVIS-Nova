import Foundation
import Combine
import AppKit

struct JARVISTask: Identifiable {
    let id: UUID
    let title: String
    let deadline: Date
    let isReminder: Bool

    init(title: String, deadline: Date, isReminder: Bool) {
        self.id = UUID()
        self.title = title
        self.deadline = deadline
        self.isReminder = isReminder
    }

    var remainingSeconds: Int {
        max(0, Int(deadline.timeIntervalSinceNow.rounded(.up)))
    }

    var countdown: String {
        let seconds = remainingSeconds
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}


enum JARVISTaskCountdown {
    static func string(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.up)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainder = seconds % 60
        if hours > 0 { return String(format: "%02d:%02d:%02d", hours, minutes, remainder) }
        return String(format: "%02d:%02d", minutes, remainder)
    }
}

@MainActor
final class TaskManager: ObservableObject {
    @Published private(set) var tasks: [JARVISTask] = []

    var onComplete: ((JARVISTask) -> Void)?

    private var workItems: [UUID: DispatchWorkItem] = [:]

    func add(title: String, seconds: Int, isReminder: Bool) {
        guard seconds > 0 else { return }

        let task = JARVISTask(
            title: title,
            deadline: Date().addingTimeInterval(TimeInterval(seconds)),
            isReminder: isReminder
        )

        tasks.append(task)

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }

            guard let index = self.tasks.firstIndex(where: { $0.id == task.id }) else {
                return
            }

            let completedTask = self.tasks.remove(at: index)
            self.workItems.removeValue(forKey: task.id)
            NSSound.beep()
            NSSound.beep()
            self.onComplete?(completedTask)
        }

        workItems[task.id] = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .seconds(seconds),
            execute: work
        )
    }

    func cancel(_ id: UUID) {
        workItems[id]?.cancel()
        workItems.removeValue(forKey: id)
        tasks.removeAll { $0.id == id }
    }

    func cancelAll() {
        for work in workItems.values {
            work.cancel()
        }
        workItems.removeAll()
        tasks.removeAll()
    }
}