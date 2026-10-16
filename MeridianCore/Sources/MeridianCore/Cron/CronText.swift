import Foundation

/// One field of the expression under the input, with its name (`32` · `day`).
public struct CronFieldChip: Equatable, Sendable {
    public let text: String
    public let label: String
    public let isError: Bool
}

/// One of the next runs: `Fri 16 Oct 02:00` (UTC) · `Fri 07:30` (this phone).
public struct CronRunRow: Equatable, Sendable {
    public let utc: String
    public let local: String
}

/// Tools › Cron wording (spec §4.6). Runs come from `CronExpression.nextRuns`, which
/// applies the gap/overlap rule in the Evaluate-in zone.
public enum CronText {
    public static func fieldChips(_ text: String, dialect: CronDialect, errorField: Int?) -> [CronFieldChip] {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("@") { return [CronFieldChip(text: trimmed, label: "macro", isError: false)] }
        let names = labels(dialect)
        return trimmed.split(whereSeparator: \.isWhitespace).enumerated().map { index, field in
            CronFieldChip(text: String(field), label: index < names.count ? names[index] : "extra",
                          isError: errorField == index + 1)
        }
    }

    /// `min · hour · day · month · weekday`, under a valid expression.
    public static func fieldLabels(_ dialect: CronDialect) -> String {
        labels(dialect).prefix(dialect == .unix ? 5 : 6).joined(separator: " · ")
    }

    /// A second line under some errors, saying what to do instead.
    public static func hint(for error: CronError, dialect: CronDialect) -> String? {
        if dialect == .unix, error.message.contains("day-of-month:"),
           let number = error.message.firstMatch(of: /: (\d+) is outside 1–31/).flatMap({ Int($0.output.1) }), number > 31 {
            return "Unix cron has no “last day” value. Use 28–31, or switch the dialect to Quartz for L."
        }
        if error.message.contains("is Quartz only") {
            return "Switch the dialect to Quartz to use L, W and #."
        }
        return nil
    }

    public static func runRow(_ run: ScheduledRun, device: Zone) -> CronRunRow {
        let utc = ZoneClock.local(run.instant, in: .utc)
        let local = ZoneClock.local(run.instant, in: device)
        return CronRunRow(utc: "\(utc.date.shortText) \(ZoneClock.wallTime(run.instant, in: .utc))",
                          local: "\(local.date.weekdayText) \(ZoneClock.wallTime(run.instant, in: device))")
    }

    /// `Local · IST` over the local column.
    public static func localHeader(device: Zone, at instant: Date) -> String {
        "Local · " + ZoneClock.state(device, at: instant).shortName
    }

    /// `Servers usually schedule in UTC. That is 07:30 on this phone.`: the second
    /// sentence only when every run lands on the same local time.
    public static func phoneNote(runs: [ScheduledRun], evaluateIn zone: Zone, device: Zone) -> String? {
        var sentences: [String] = []
        if zone.isUTC { sentences.append("Servers usually schedule in UTC.") }
        let times = Set(runs.map { ZoneClock.wallTime($0.instant, in: device) })
        if device != zone, !(zone.isUTC && device.isUTC), times.count == 1, let time = times.first {
            sentences.append("That is \(time) on this phone.")
        }
        return sentences.isEmpty ? nil : sentences.joined(separator: " ")
    }

    /// For the first run the gap/overlap rule moved (spec §5.2).
    public static func dstNote(runs: [ScheduledRun], zone: Zone, zoneName: String) -> String? {
        guard let run = runs.first(where: { $0.kind != .exact }) else { return nil }
        let asked = "\(run.wallTime.date.shortText) \(ClockTime(run.wallTime.hour, run.wallTime.minute).text)"
        switch run.kind {
        case .skipped:
            return "\(asked) doesn't exist in \(zoneName); that run is at "
                + "\(ZoneClock.timeWithAbbreviation(run.instant, in: zone)). Your scheduler may differ."
        case .repeated:
            return "\(asked) happens twice in \(zoneName); it runs once, at the first "
                + "(\(ZoneClock.shortName(zone, at: run.instant))). Your scheduler may differ."
        case .exact:
            return nil
        }
    }

    public static let neverRuns = EpochNote(title: "Never runs",
                                            detail: "The syntax is valid, but no date in the next 400 years matches it.")

    /// The expression, its description, then one line per run with offsets.
    public static func copyText(expression: String, description: String, runs: [ScheduledRun], device: Zone) -> String {
        let lines = runs.map { run in
            let utc = ZoneClock.local(run.instant, in: .utc)
            return "\(utc.date.shortText) \(utc.date.year) \(ZoneClock.wallTime(run.instant, in: .utc)) UTC · "
                + ZoneClock.copyText(run.instant, in: device)
        }
        return (["\(expression) · \(description)"] + lines).joined(separator: "\n")
    }

    private static func labels(_ dialect: CronDialect) -> [String] {
        switch dialect {
        case .unix: ["min", "hour", "day", "month", "weekday"]
        case .quartz: ["sec", "min", "hour", "day", "month", "weekday", "year"]
        }
    }
}
