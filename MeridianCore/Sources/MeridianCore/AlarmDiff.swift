import Foundation

/// Which system alarms to cancel and which fire dates to schedule so the scheduled set
/// matches `wanted` (decision BC). Used for sessions; written for M7's alarms too.
///
/// `stored` is what the app recorded (alarm id → fire date); `live` is what the system
/// reports now (AlarmKit's update stream isn't trusted while suspended, M0.5 test 9).
/// A stored alarm is kept only if it is live and fires at a wanted date; each wanted
/// date is matched at most once.
public enum AlarmDiff {
    public struct Plan: Equatable, Sendable {
        /// Sorted by id, so results are stable.
        public let cancel: [UUID]
        /// Sorted by date.
        public let schedule: [Date]
    }

    public static func plan(wanted: [Date], stored: [UUID: Date], live: Set<UUID>) -> Plan {
        var unmatched = wanted.sorted()
        var cancel: [UUID] = []
        for (id, date) in stored.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
            if live.contains(id), let index = unmatched.firstIndex(of: date) {
                unmatched.remove(at: index)
            } else {
                cancel.append(id)
            }
        }
        return Plan(cancel: cancel, schedule: unmatched)
    }
}
