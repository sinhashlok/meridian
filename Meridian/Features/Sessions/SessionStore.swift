import Foundation
import MeridianCore
import SwiftData

/// One focus phase of a finished or stopped session (spec §7 `Session`, decision BB),
/// for daily totals.
@Model
final class SessionRecord {
    var start: Date
    var end: Date
    /// Time actually focused (the interval minus pauses).
    var focusSeconds: Int

    init(_ record: FocusRecord) {
        start = record.interval.start
        end = record.interval.end
        focusSeconds = record.seconds
    }

    var focusRecord: FocusRecord {
        FocusRecord(interval: DateInterval(start: start, end: max(end, start)), seconds: focusSeconds)
    }
}

/// The active session and its lengths, kept in `UserDefaults` as JSON (decision BB) so the
/// screen (`@AppStorage`) and the Live Activity buttons (intents, maybe with no window)
/// see the same value. Every change goes through here.
@MainActor enum SessionStore {
    static let sessionKey = "session.state"
    static let lengthsKey = "session.lengths"

    private static var defaults: UserDefaults { .standard }

    static var session: PomodoroSession? {
        get { defaults.data(forKey: sessionKey).flatMap { try? JSONDecoder().decode(PomodoroSession.self, from: $0) } }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: sessionKey)
            } else {
                defaults.removeObject(forKey: sessionKey)
            }
        }
    }

    static var lengths: SessionLengths {
        get {
            defaults.data(forKey: lengthsKey).flatMap { try? JSONDecoder().decode(SessionLengths.self, from: $0) }
                ?? .standard
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: lengthsKey) }
    }

    static func start(at now: Date) {
        session = .start(lengths, at: now)
    }

    /// Applies a Core change (pause, +5 min, skip, resume) if a session is running.
    static func update(_ change: (inout PomodoroSession) -> Void) {
        guard var current = session else { return }
        change(&current)
        session = current
    }

    /// Stop, or dismiss a finished session: log its focus so far, then clear it.
    static func finish(at now: Date, in context: ModelContext) {
        guard let current = session else { return }
        for record in current.focusRecords(until: now) where record.seconds > 0 {
            context.insert(SessionRecord(record))
        }
        try? context.save()
        session = nil
    }

    /// `-MeridianSession demo|paused|done|idle`, relative to the (frozen) clock: the
    /// Sessions board (Focus 1 of 4 with 18:42 left), the same paused, one just finished,
    /// or none.
    static func applyDebugLaunch(now: Date) {
        switch DebugLaunch.session {
        case "demo": session = .start(.standard, at: now.addingTimeInterval(-378))
        case "paused":
            var paused = PomodoroSession.start(.standard, at: now.addingTimeInterval(-378))
            paused.pause(at: now)
            session = paused
        case "done": session = .start(.standard, at: now.addingTimeInterval(-120 * 60))
        case "idle": session = nil
        default: break
        }
    }
}
