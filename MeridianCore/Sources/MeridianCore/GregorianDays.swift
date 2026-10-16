/// Integer conversions between a proleptic Gregorian date and a day count since
/// 1970-01-01, after Howard Hinnant's `days_from_civil` / `civil_from_days`
/// (https://howardhinnant.github.io/date_algorithms.html).
///
/// Used where exactness matters more than convenience: Foundation's Gregorian
/// `Calendar` switches to the Julian calendar before 15 Oct 1582, and going through
/// `Date` would put nanosecond values into a `Double`.
enum GregorianDays {
    /// Days since 1970-01-01 for a valid year/month/day (negative before 1970).
    static func days(year: Int64, month: Int64, day: Int64) -> Int64 {
        let y = month <= 2 ? year - 1 : year
        let era = floorDiv(y, 400)
        let yearOfEra = y - era * 400                                          // 0...399
        let shiftedMonth = month > 2 ? month - 3 : month + 9                   // March = 0
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1                 // 0...365
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    /// The year/month/day for a day count since 1970-01-01.
    static func date(fromDays days: Int64) -> (year: Int64, month: Int64, day: Int64) {
        let z = days + 719_468
        let era = floorDiv(z, 146_097)
        let dayOfEra = z - era * 146_097                                       // 0...146096
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shiftedMonth = (5 * dayOfYear + 2) / 153                           // March = 0
        let day = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1
        let month = shiftedMonth < 10 ? shiftedMonth + 3 : shiftedMonth - 9
        return (yearOfEra + era * 400 + (month <= 2 ? 1 : 0), month, day)
    }

    static func isLeapYear(_ year: Int64) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    static func daysInMonth(year: Int64, month: Int64) -> Int64 {
        switch month {
        case 2: isLeapYear(year) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }
}

/// Division rounding toward negative infinity, like Python's `//`.
/// Swift's `/` rounds toward zero, which is wrong for negative epochs (-1500 ms → -2 s).
func floorDiv(_ a: Int64, _ b: Int64) -> Int64 {
    let q = a / b
    return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
}
