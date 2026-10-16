import Foundation

/// What the Epoch input holds: digits (an epoch) or a date-time to turn into one.
public enum EpochInputKind: Equatable, Sendable { case empty, epoch, dateTime }

/// One result row with its 44pt copy button: `UTC` · `Thu 15 Oct 2026 10:40:00`.
/// `copyText` always carries the zone (CLAUDE.md: copied times include the offset).
public struct EpochRow: Equatable, Sendable {
    public let label: String
    public let value: String
    public let copyText: String
}

/// A neutral note with a title and a detail (the ambiguity note).
public struct EpochNote: Equatable, Sendable {
    public let title: String
    public let detail: String
}

/// `Replace with 0`: the button label's character and the corrected input.
public struct EpochFix: Equatable, Sendable {
    public let label: String
    public let input: String
}

/// What the first `digits` digits mean in `unit` (`10 · seconds · Thu 15 Oct 2026`).
public struct EpochReading: Equatable, Sendable {
    public let digits: Int
    public let unit: EpochUnit
    public let prefix: String
    public let dateText: String
}

/// Why an epoch input has no result, shown inline with a symbol (spec §4.6).
public struct EpochProblem: Equatable, Sendable {
    public let title: String
    public let detail: String
    /// 1-based position of the offending character in the input, for the caret.
    public let characterIndex: Int?
    public let fix: EpochFix?
    /// Too-long input: what each standard length of it would mean (decision W).
    public let readings: [EpochReading]
}

/// A zone-less date-time (`2026-10-25 01:30`), before a zone is chosen.
public struct LocalInput: Equatable, Sendable {
    public let time: LocalDateTime
    public let second: Int
    public let nanoseconds: Int32
    /// Fraction digits typed, so the ISO row keeps the same precision.
    public let fractionDigits: Int
}

/// One way to read a zone-less time: `First · BST` / `UTC+1 → 00:30 UTC`.
public struct ZonelessOption: Equatable, Sendable {
    public let occurrence: Occurrence
    public let title: String
    public let detail: String
    public let value: EpochValue
}

/// A zone-less time read in the Interpret-as zone: one option, or First and Second when
/// the zone repeats that hour, plus the note the gap/overlap rule calls for (spec §5.2).
public struct ZonelessReading: Equatable, Sendable {
    public let options: [ZonelessOption]
    let kind: Resolution.Kind
    let wall: String
    let zoneName: String
    let dateText: String
    let skippedTo: String

    public func option(for occurrence: Occurrence) -> ZonelessOption {
        options.first { $0.occurrence == occurrence } ?? options[0]
    }

    /// `01:30 happens twice in London on Sun 25 Oct. Showing the first (BST). Your
    /// scheduler may differ.`, the skipped-time note, or `nil` for an ordinary time.
    public func note(for occurrence: Occurrence) -> String? {
        switch kind {
        case .exact:
            return nil
        case .repeated:
            let which = occurrence == .first ? "first" : "second"
            let name = option(for: occurrence).title.components(separatedBy: " · ").last ?? ""
            return "\(wall) happens twice in \(zoneName) on \(dateText). Showing the \(which) (\(name)). "
                + "Your scheduler may differ."
        case .skipped:
            return "\(wall) doesn't exist in \(zoneName) on \(dateText). Showing \(skippedTo), the next valid time. "
                + "Your scheduler may differ."
        }
    }
}

/// Tools › Epoch wording (spec §4.6). Dates are formatted with integer maths from
/// `EpochValue`, so nanoseconds and years 0001–9999 stay exact (decision C).
public enum EpochText {
    public static func kind(of input: String) -> EpochInputKind {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .empty }
        return trimmed.contains(":") || trimmed.contains(/\d{4}-\d{2}-\d{2}/) ? .dateTime : .epoch
    }

    /// UTC · Local · ISO 8601 · Relative · Unix seconds (spec §4.6 order). `isoZone` is
    /// UTC for epochs and the Interpret-as zone for zone-less input.
    public static func rows(_ value: EpochValue, precision: EpochUnit, local: Zone, isoZone: Zone, now: Date) -> [EpochRow] {
        let utc = dateTime(value, in: .utc)
        let localText = dateTime(value, in: local)
        let localLabel = ZoneClock.label(local, at: value.date)
        let iso = isoString(value, in: isoZone, precision: precision)
        let ago = relative(value, now: now)
        return [
            EpochRow(label: "UTC", value: utc, copyText: utc + " UTC"),
            EpochRow(label: "Local · \(localLabel)", value: localText, copyText: "\(localText) \(localLabel)"),
            EpochRow(label: "ISO 8601", value: iso, copyText: iso),
            EpochRow(label: "Relative", value: ago, copyText: ago),
            EpochRow(label: "Unix seconds", value: String(value.seconds), copyText: String(value.seconds)),
        ]
    }

    /// `Thu 15 Oct 2026 10:40:00` on the wall clock of `zone` at that instant.
    public static func dateTime(_ value: EpochValue, in zone: Zone) -> String {
        let local = Self.local(value, in: zone)
        return "\(weekdays[local.weekday - 1]) \(local.day) \(months[Int(local.month) - 1]) \(pad(local.year, 4)) "
            + "\(pad(local.secondOfDay / 3600, 2)):\(pad(local.secondOfDay / 60 % 60, 2)):\(pad(local.secondOfDay % 60, 2))"
    }

    /// `27 Jul 1970` (UTC), for the reading cards.
    public static func shortDate(_ value: EpochValue) -> String {
        let local = Self.local(value, in: .utc)
        return "\(local.day) \(months[Int(local.month) - 1]) \(pad(local.year, 4))"
    }

    /// `2026-10-25T01:30:00+01:00`, or `…Z` when `zone` is UTC. Fraction digits as in
    /// `utcISOString`: omitted when zero, else `precision`'s digits.
    public static func isoString(_ value: EpochValue, in zone: Zone, precision: EpochUnit) -> String {
        guard !zone.isUTC else { return value.utcISOString(precision: precision) }
        let local = Self.local(value, in: zone)
        var text = "\(pad(local.year, 4))-\(pad(local.month, 2))-\(pad(local.day, 2))T"
            + "\(pad(local.secondOfDay / 3600, 2)):\(pad(local.secondOfDay / 60 % 60, 2)):\(pad(local.secondOfDay % 60, 2))"
        let digits = precision.fractionDigits
        if digits > 0 {
            let fraction = Int64(value.nanoseconds) / pow10(9 - digits)
            if fraction != 0 { text += "." + pad(fraction, digits) }
        }
        let offset = Int64(local.offset)
        let sign = offset < 0 ? "-" : "+"
        return text + sign + pad(abs(offset) / 3600, 2) + ":" + pad(abs(offset) % 3600 / 60, 2)
    }

    /// Elapsed time (decision AE): `just now`, `13 min`, `4 h 52 min`, `8 days`,
    /// `21 months`, `56 years`, with `ago` or `in`.
    public static func relative(_ value: EpochValue, now: Date) -> String {
        let difference = value.seconds - Int64(now.timeIntervalSince1970.rounded(.down))
        let span = abs(difference)
        let text: String
        switch span {
        case ..<60:
            return "just now"
        case ..<3600:
            text = "\(span / 60) min"
        case ..<86_400:
            let hours = span / 3600, minutes = span % 3600 / 60
            text = minutes == 0 ? "\(hours) h" : "\(hours) h \(minutes) min"
        case ..<(60 * 86_400):
            let days = span / 86_400
            text = days == 1 ? "1 day" : "\(days) days"
        case ..<(2 * secondsPerYear):
            text = "\(span / (secondsPerYear / 12)) months"
        default:
            text = "\(span / secondsPerYear) years"
        }
        return difference > 0 ? "in \(text)" : "\(text) ago"
    }

    /// `13 digits` → `milliseconds`; past 19 digits, `no unit fits`.
    public static func unitChip(for input: String, unit: EpochUnit?) -> (digits: String, unit: String) {
        let count = significantDigits(of: input).count
        let read = count > 19 ? "no unit fits" : (unit ?? EpochParser.detectUnit(significantDigits: count).0).rawValue
        return ("\(count) digits", read)
    }

    /// For 11–12, 14–15 and 17–18 digits: which reading is shown and why.
    public static func ambiguity(_ result: EpochParseResult, input: String, now: Date) -> EpochNote? {
        let count = significantDigits(of: input).count
        let (preferred, others) = EpochParser.detectUnit(significantDigits: count)
        guard !others.isEmpty else { return nil }
        let candidates = ([preferred] + others).compactMap { unit -> (EpochUnit, Int64)? in
            guard let value = try? EpochParser.parse(input, as: unit).value else { return nil }
            return (unit, abs(value.seconds - Int64(now.timeIntervalSince1970)))
        }
        let closest = candidates.min { $0.1 < $1.1 }?.0
        var detail = result.unit == closest
            ? "Showing \(result.unit.rawValue) because it is closer to today."
            : "Showing \(result.unit.rawValue), as you chose."
        if candidates.allSatisfy({ $0.1 > 10 * secondsPerYear }) {
            detail += " Neither reading is recent, so a digit may be missing."
        }
        return EpochNote(title: "\(count) digits is not a standard length", detail: detail)
    }

    /// The reading cards for an ambiguous input: `18 Nov 2537` per unit.
    public static func readings(of input: String, units: [EpochUnit]) -> [EpochReading] {
        let digits = significantDigits(of: input)
        return units.map { unit in
            let text = (try? EpochParser.parse(input, as: unit)).map { shortDate($0.value) } ?? "after 9999"
            return EpochReading(digits: digits.count, unit: unit, prefix: digits, dateText: text)
        }
    }

    /// Why `input` (an epoch, read as `unit` if given) has no result, or `nil`.
    public static func problem(in input: String, unit: EpochUnit? = nil) -> EpochProblem? {
        guard kind(of: input) == .epoch else { return nil }
        if let bad = badCharacter(in: input) { return bad }

        let digits = significantDigits(of: input)
        if digits.count > 19 {
            let readings = [(10, EpochUnit.seconds), (13, .milliseconds), (16, .microseconds), (19, .nanoseconds)]
                .map { length, unit in
                    let prefix = String(digits.prefix(length))
                    let text = (try? EpochParser.parse(prefix, as: unit)).map { weekdayDate($0.value) } ?? "out of range"
                    return EpochReading(digits: length, unit: unit, prefix: prefix, dateText: text)
                }
            return EpochProblem(
                title: "Out of range: \(digits.count) digits is longer than any epoch",
                detail: "Nanoseconds is the longest unit (19 digits) and stops at \(lastNanosecond) UTC. "
                    + "Were two values pasted together?",
                characterIndex: nil, fix: nil, readings: readings)
        }

        do {
            _ = try EpochParser.parse(input, as: unit)
            return nil
        } catch .tooLarge {
            return EpochProblem(title: "Out of range: past the last nanosecond epoch",
                                detail: "Nanoseconds stop at \(lastNanosecond) UTC (\(Int64.max)).",
                                characterIndex: nil, fix: nil, readings: [])
        } catch .outOfRange {
            let read = unit ?? EpochParser.detectUnit(significantDigits: digits.count).0
            let side = input.trimmingCharacters(in: .whitespaces).hasPrefix("-") ? "before the year 1" : "after the year 9999"
            return EpochProblem(title: "Out of range: as \(read.rawValue) this is \(side)",
                                detail: "Dates run from year 1 to 9999.", characterIndex: nil, fix: nil, readings: [])
        } catch {
            return nil
        }
    }

    /// Reads a zone-less time in `zone` with the gap/overlap rule (`ZoneClock.resolve`).
    public static func zoneless(_ input: LocalInput, in zone: Zone, zoneName: String) -> ZonelessReading {
        func value(_ resolution: Resolution) -> EpochValue {
            let seconds = Int64(resolution.instant.timeIntervalSince1970.rounded())
            // A skipped time moves to the next valid minute exactly (spec §5.2).
            guard resolution.kind != .skipped else { return EpochValue(seconds: seconds, nanoseconds: 0) }
            return EpochValue(seconds: seconds + Int64(input.second), nanoseconds: input.nanoseconds)
        }
        func option(_ occurrence: Occurrence, _ resolution: Resolution) -> ZonelessOption {
            let state = ZoneClock.state(zone, at: resolution.instant)
            let title = (occurrence == .first ? "First" : "Second") + " · " + state.shortName
            return ZonelessOption(occurrence: occurrence, title: title,
                                  detail: "\(ZoneClock.offsetLabel(seconds: state.offsetSeconds)) → "
                                      + "\(ZoneClock.wallTime(resolution.instant, in: .utc)) UTC",
                                  value: value(resolution))
        }

        let first = ZoneClock.resolve(input.time, in: zone, occurrence: .first)
        var options = [option(.first, first)]
        if first.kind == .repeated {
            options.append(option(.second, ZoneClock.resolve(input.time, in: zone, occurrence: .second)))
        }
        return ZonelessReading(
            options: options, kind: first.kind,
            wall: ClockTime(input.time.hour, input.time.minute).text, zoneName: zoneName,
            dateText: input.time.date.shortText,
            skippedTo: ZoneClock.timeWithAbbreviation(first.instant, in: zone))
    }

    // MARK: Private

    private static let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    /// Average Gregorian year, 365.2425 days.
    private static let secondsPerYear: Int64 = 31_556_952
    /// `Int64.max` nanoseconds.
    private static let lastNanosecond = "2262-04-11 23:47:16"

    /// The wall clock of `zone` at `value`, from integer day maths.
    private static func local(_ value: EpochValue, in zone: Zone)
        -> (year: Int64, month: Int64, day: Int64, weekday: Int, secondOfDay: Int64, offset: Int) {
        let offset = zone.timeZone.secondsFromGMT(for: value.date)
        let seconds = value.seconds + Int64(offset)
        let days = floorDiv(seconds, 86_400)
        let (year, month, day) = GregorianDays.date(fromDays: days)
        let weekday = Int(days + 3 - floorDiv(days + 3, 7) * 7) + 1          // 1970-01-01 was a Thursday
        return (year, month, day, weekday, seconds - days * 86_400, offset)
    }

    /// `Thu 15 Oct 2026` (UTC).
    private static func weekdayDate(_ value: EpochValue) -> String {
        let local = Self.local(value, in: .utc)
        return "\(weekdays[local.weekday - 1]) \(local.day) \(months[Int(local.month) - 1]) \(pad(local.year, 4))"
    }

    /// The digits that count: separators and sign removed, leading zeros dropped.
    private static func significantDigits(of input: String) -> String {
        let digits = input.filter(\.isNumber)
        let trimmed = String(digits.drop(while: { $0 == "0" }))
        return trimmed.isEmpty ? "0" : trimmed
    }

    /// The first character that isn't a digit, separator or leading minus.
    private static func badCharacter(in input: String) -> EpochProblem? {
        var seenContent = false
        for (offset, character) in input.enumerated() {
            if character.isWhitespace || character == "_" || character == "," { continue }
            if character == "-", !seenContent { seenContent = true; continue }
            seenContent = true
            if ("0"..."9").contains(character) { continue }

            let index = offset + 1
            let lookAlike: (digit: String, word: String)? = switch character {
            case "O", "o": ("0", "zero")
            case "l", "I": ("1", "one")
            default: nil
            }
            let title = character.isLetter
                ? "Contains a letter: character \(index) is “\(character)”" + (lookAlike.map { ", not \($0.word)" } ?? "")
                : "Not a whole number: character \(index) is “\(character)”"
            let fix = lookAlike.map { lookAlike in
                var fixed = Array(input)
                fixed[offset] = Character(lookAlike.digit)
                return EpochFix(label: lookAlike.digit, input: String(fixed))
            }
            return EpochProblem(title: title, detail: "Epochs are digits only, with an optional leading minus.",
                                characterIndex: index, fix: fix, readings: [])
        }
        return nil
    }
}

extension EpochParser {
    /// Parses `YYYY-MM-DD[T ]HH:MM[:SS[.fffffffff]]` with no zone. Pair with
    /// `EpochText.zoneless` when `parseISO8601` throws `.missingZone`.
    public static func parseLocalDateTime(_ input: String) throws(EpochError) -> LocalInput {
        let pattern = /(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,9}))?)?/
        guard let match = input.trimmingCharacters(in: .whitespaces).wholeMatch(of: pattern) else {
            throw .invalidISO8601
        }
        let (_, y, mo, d, h, mi, s, fraction) = match.output
        let hour = Int(h)!, minute = Int(mi)!, second = s.map { Int($0)! } ?? 0
        guard let date = CivilDate(iso: "\(y)-\(mo)-\(d)"), (0...23).contains(hour), (0...59).contains(minute),
              (0...59).contains(second)
        else { throw .invalidISO8601 }
        let nanoseconds = fraction.map { Int32($0)! * Int32(pow10(9 - $0.count)) } ?? 0
        return LocalInput(time: LocalDateTime(date: date, hour: hour, minute: minute), second: second,
                          nanoseconds: nanoseconds, fractionDigits: fraction?.count ?? 0)
    }
}

extension ZoneClock {
    /// `11:40 BST`, or `16:25 UTC+5:45` for zones without an abbreviation.
    public static func timeWithAbbreviation(_ instant: Date, in zone: Zone) -> String {
        wallTime(instant, in: zone) + " " + shortName(zone, at: instant)
    }
}

private func pad(_ value: Int64, _ width: Int) -> String {
    let digits = String(value)
    return String(repeating: "0", count: max(0, width - digits.count)) + digits
}

private func pow10(_ exponent: Int) -> Int64 {
    (0..<exponent).reduce(1) { result, _ in result * 10 }
}
