import AppIntents
import Foundation

// Live Activity buttons (decision BA). iOS runs a `LiveActivityIntent` in the app's
// process, so `perform()` reaches the app's `LiveActivityActions`. These types are
// compiled into the widget too (its buttons name them); there `LiveActivityActions` is a
// stub that is never called.
// Hidden from Shortcuts: they only make sense on the activity they belong to.

enum LiveSessionAction: String, Sendable {
    case pause, resume, addFive, skip, stop
}

enum LiveTimerAction: String, Sendable {
    case pause, resume, addMinute, cancel
}

struct SessionActionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Session action"
    static let isDiscoverable = false

    @Parameter(title: "Action") var action: String

    init() { action = LiveSessionAction.pause.rawValue }
    init(_ action: LiveSessionAction) { self.action = action.rawValue }

    func perform() async throws -> some IntentResult {
        if let action = LiveSessionAction(rawValue: action) { await LiveActivityActions.session(action) }
        return .result()
    }
}

struct TimerActionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Timer action"
    static let isDiscoverable = false

    @Parameter(title: "Action") var action: String
    @Parameter(title: "Timer") var timerID: String

    init() {
        action = LiveTimerAction.pause.rawValue
        timerID = ""
    }

    init(_ action: LiveTimerAction, timerID: UUID) {
        self.action = action.rawValue
        self.timerID = timerID.uuidString
    }

    func perform() async throws -> some IntentResult {
        if let action = LiveTimerAction(rawValue: action), let id = UUID(uuidString: timerID) {
            await LiveActivityActions.timer(action, id: id)
        }
        return .result()
    }
}
