import Foundation

/// One completed lap: its own length (`splitMs`) and the stopwatch total when it ended.
public struct Lap: Equatable, Sendable {
    public let number: Int
    public let splitMs: Int64
    public let totalMs: Int64

    public init(number: Int, splitMs: Int64, totalMs: Int64) {
        self.number = number
        self.splitMs = splitMs
        self.totalMs = totalMs
    }
}

/// The stopwatch (spec §4.4, decision AP). Stores when it started and whole milliseconds,
/// never a running counter, so it survives the app being killed.
public struct Stopwatch: Codable, Hashable, Sendable {
    /// Running since; `nil` when stopped.
    public private(set) var startedAt: Date?
    /// Elapsed before `startedAt` (earlier runs).
    public private(set) var accumulatedMs: Int64 = 0
    /// Stopwatch total at each Lap tap.
    public private(set) var lapTotalsMs: [Int64] = []

    public init() {}

    public var isRunning: Bool { startedAt != nil }

    public func elapsedMs(at now: Date) -> Int64 {
        guard let startedAt else { return accumulatedMs }
        // Nearest ms: a Date is a Double, so 62.345 s can come back as 62344.9999 ms.
        return accumulatedMs + max(0, Int64((now.timeIntervalSince(startedAt) * 1000).rounded()))
    }

    public var laps: [Lap] {
        zip(lapTotalsMs, [0] + lapTotalsMs).enumerated().map { index, pair in
            Lap(number: index + 1, splitMs: pair.0 - pair.1, totalMs: pair.0)
        }
    }

    /// The lap in progress (since the last Lap tap).
    public func currentLapMs(at now: Date) -> Int64 {
        elapsedMs(at: now) - (lapTotalsMs.last ?? 0)
    }

    public mutating func start(at now: Date) {
        guard startedAt == nil else { return }
        startedAt = now
    }

    public mutating func stop(at now: Date) {
        guard startedAt != nil else { return }
        accumulatedMs = elapsedMs(at: now)
        startedAt = nil
    }

    public mutating func lap(at now: Date) {
        guard isRunning else { return }
        lapTotalsMs.append(elapsedMs(at: now))
    }

    public mutating func reset() {
        self = Stopwatch()
    }
}

public enum LapMark: Sendable { case fastest, slowest }

/// Stopwatch wording (decision AP).
public enum StopwatchText {
    /// `01:02.34` under an hour, `1:02:03.45` from an hour. Centiseconds are truncated:
    /// a stopwatch shows the hundredth that has started.
    public static func time(ms: Int64) -> String {
        let ms = max(0, ms)
        let centis = ms % 1000 / 10, seconds = ms / 1000 % 60, minutes = ms / 60_000 % 60, hours = ms / 3_600_000
        return hours > 0
            ? String(format: "%lld:%02lld:%02lld.%02lld", hours, minutes, seconds, centis)
            : String(format: "%02lld:%02lld.%02lld", minutes, seconds, centis)
    }

    /// Fastest and slowest lap by number, from 3 laps. Ties mark the earliest; if every
    /// lap is the same length, none.
    public static func marks(_ laps: [Lap]) -> [Int: LapMark] {
        guard laps.count >= 3,
              let fastest = laps.min(by: { $0.splitMs < $1.splitMs }),
              let slowest = laps.max(by: { $0.splitMs < $1.splitMs }),    // min/max keep the first of equals
              fastest.splitMs != slowest.splitMs
        else { return [:] }
        return [fastest.number: .fastest, slowest.number: .slowest]
    }

    /// `lap,split_ms,total_ms,split,total` and one row per completed lap.
    public static func csv(_ laps: [Lap]) -> String {
        (["lap,split_ms,total_ms,split,total"]
            + laps.map { "\($0.number),\($0.splitMs),\($0.totalMs),\(time(ms: $0.splitMs)),\(time(ms: $0.totalMs))" })
            .joined(separator: "\n")
    }
}
