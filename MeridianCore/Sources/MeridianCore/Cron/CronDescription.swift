import Foundation

/// Plain-English cron descriptions for the Cron tool (spec §4.6):
/// "At 02:00, Monday through Friday", "Every 15 minutes".
extension CronExpression: CustomStringConvertible {
    public var description: String {
        let time = timePhrase()
        var parts = [time.text]
        if let days = dayPhrase() {
            parts.append(days)
        } else if time.isSpecific {
            parts.append("every day")
        }
        if let months = monthPhrase() { parts.append(months) }
        if let years = yearPhrase() { parts.append(years) }
        return parts.joined(separator: ", ")
    }

    // MARK: Time

    private var rawMinute: String { dialect == .quartz ? rawFields[1] : rawFields[0] }
    private var rawHour: String { dialect == .quartz ? rawFields[2] : rawFields[1] }

    private func timePhrase() -> (text: String, isSpecific: Bool) {
        let allMinutes = minutes.count == 60, allHours = hours.count == 24
        let singleSecond = seconds.count == 1

        if seconds.count == 60, allMinutes, allHours { return ("Every second", false) }
        if singleSecond, seconds[0] == 0 {
            if allMinutes, allHours { return ("Every minute", false) }
            if allHours, let step = step(in: rawMinute) { return ("Every \(step) minutes", false) }
        }
        if singleSecond, minutes.count == 1 {
            if allHours { return ("At minute \(minutes[0]) of every hour", false) }
            if let step = step(in: rawHour) { return ("At minute \(minutes[0]) of every \(step) hours", false) }
            if hours.count * minutes.count <= 6 {
                let times = hours.map { clock($0, minutes[0], seconds[0]) }
                return ("At " + englishList(times), true)
            }
        }
        if singleSecond, hours.count == 1, minutes.count <= 6 {
            return ("At " + englishList(minutes.map { clock(hours[0], $0, seconds[0]) }), true)
        }
        let secondsPrefix = singleSecond && seconds[0] == 0 ? "" : "At seconds \(numberList(seconds)), "
        let start = secondsPrefix.isEmpty ? "At" : "at"
        return (secondsPrefix + "\(start) minutes \(numberList(minutes)) of hours \(numberList(hours))", false)
    }

    private func clock(_ hour: Int, _ minute: Int, _ second: Int) -> String {
        twoDigits(hour) + ":" + twoDigits(minute) + (second == 0 ? "" : ":" + twoDigits(second))
    }

    /// `n` from `*/n` or `0/n`.
    private func step(in field: String) -> Int? {
        let parts = field.split(separator: "/")
        guard parts.count == 2, parts[0] == "*" || parts[0] == "0", let step = Int(parts[1]) else { return nil }
        return step
    }

    // MARK: Days

    private static let weekdayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private static let monthNames = ["January", "February", "March", "April", "May", "June", "July",
                                     "August", "September", "October", "November", "December"]
    private static let ordinals = ["first", "second", "third", "fourth", "fifth"]

    private func dayPhrase() -> String? {
        let monthDay = dayOfMonth.map(monthDayPhrase)
        let weekDay = dayOfWeek.map { weekDayPhrase($0, alone: dayOfMonth == nil) }
        switch (monthDay, weekDay) {
        case (nil, nil): return nil
        case (let monthDay?, nil): return monthDay
        case (nil, let weekDay?): return weekDay
        case (let monthDay?, let weekDay?): return daysUseOr ? "\(monthDay) and \(weekDay)" : "\(monthDay), \(weekDay)"
        }
    }

    private func monthDayPhrase(_ rule: DayOfMonthRule) -> String {
        switch rule {
        case .days(let days):
            let sorted = days.sorted()
            return sorted.count == 1 ? "on day \(sorted[0]) of the month" : "on days \(numberList(sorted)) of the month"
        case .last(0): return "on the last day of the month"
        case .last(let offset): return "\(offset) day\(offset == 1 ? "" : "s") before the last day of the month"
        case .nearestWeekday(let day): return "on the weekday nearest day \(day)"
        case .lastWeekday: return "on the last weekday of the month"
        }
    }

    private func weekDayPhrase(_ rule: DayOfWeekRule, alone: Bool) -> String {
        switch rule {
        case .days(let days):
            let sorted = days.sorted()
            if sorted.count == 1 { return (alone ? "only on " : "on ") + Self.weekdayNames[sorted[0] - 1] }
            if isContiguous(sorted), sorted.count >= 3 {
                return Self.weekdayNames[sorted.first! - 1] + " through " + Self.weekdayNames[sorted.last! - 1]
            }
            return "on " + englishList(sorted.map { Self.weekdayNames[$0 - 1] })
        case .last(let weekday):
            return "on the last \(Self.weekdayNames[weekday - 1]) of the month"
        case .nth(let weekday, let n):
            return "on the \(Self.ordinals[n - 1]) \(Self.weekdayNames[weekday - 1]) of the month"
        }
    }

    // MARK: Months and years

    private func monthPhrase() -> String? {
        guard months.count < 12 else { return nil }
        let sorted = months.sorted()
        if isContiguous(sorted), sorted.count >= 3 {
            return Self.monthNames[sorted.first! - 1] + " through " + Self.monthNames[sorted.last! - 1]
        }
        return "in " + englishList(sorted.map { Self.monthNames[$0 - 1] })
    }

    private func yearPhrase() -> String? {
        guard let years else { return nil }
        return "in " + numberList(years.sorted())
    }

    // MARK: Helpers

    private func isContiguous(_ sorted: [Int]) -> Bool {
        zip(sorted, sorted.dropFirst()).allSatisfy { $1 == $0 + 1 }
    }

    /// `1–7, 15 and 20`: runs of three or more collapse to a range.
    private func numberList(_ sorted: [Int]) -> String {
        var pieces: [String] = []
        var index = 0
        while index < sorted.count {
            var end = index
            while end + 1 < sorted.count, sorted[end + 1] == sorted[end] + 1 { end += 1 }
            if end - index >= 2 {
                pieces.append("\(sorted[index])–\(sorted[end])")
            } else {
                pieces.append(contentsOf: sorted[index...end].map(String.init))
            }
            index = end + 1
        }
        return englishList(pieces)
    }

    private func englishList(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        default: return items.dropLast().joined(separator: ", ") + " and " + items.last!
        }
    }

}
