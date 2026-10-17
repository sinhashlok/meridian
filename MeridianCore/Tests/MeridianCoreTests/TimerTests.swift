import Foundation
import Testing
@testable import MeridianCore

/// Spec §4.4 timers and docs/decisions.md AJ–AN. Values checked with Python `zoneinfo`
/// on 17 Oct 2026; board values from TimerUntil.png (frozen at 2026-10-15T15:39:18Z).
@Suite("Timers")
struct TimerTests {
    static let ist = Zone("Asia/Kolkata")!
    static let london = Zone("Europe/London")!
    static let ny = Zone("America/New_York")!

    static func utc(_ iso: String) -> Date { try! EpochParser.parseISO8601(iso).date }

    static let boardNow = utc("2026-10-15T15:39:18Z")

    /// Board "Standup prep": 10 min started 15:36:00Z, so 06:42 left at 15:39:18Z.
    static func standup() -> CountdownTimer {
        .duration(seconds: 600, name: "Standup prep", now: utc("2026-10-15T15:36:00Z"))
    }

    // MARK: Remaining-time format (decision AK)

    @Test("MM:SS under an hour, HH:MM:SS from an hour", arguments: [
        (0, "00:00"), (59, "00:59"), (60, "01:00"), (402, "06:42"), (3599, "59:59"),
        (3600, "01:00:00"), (37_242, "10:20:42"), (86_399, "23:59:59"),
    ])
    func remainingFormat(seconds: Int, text: String) {
        #expect(TimerText.remaining(seconds: seconds) == text)
    }

    @Test("Remaining rounds up: 10:00 at the start, 00:00 only at the end")
    func roundsUp() {
        let start = Self.utc("2026-10-15T15:36:00Z")
        let timer = CountdownTimer.duration(seconds: 600, now: start)
        #expect(timer.remainingSeconds(at: start) == 600)
        #expect(timer.remainingSeconds(at: start.addingTimeInterval(0.5)) == 600)
        #expect(timer.remainingSeconds(at: start.addingTimeInterval(599.5)) == 1)
        #expect(timer.remainingSeconds(at: start.addingTimeInterval(600)) == 0)
        #expect(timer.remainingSeconds(at: start.addingTimeInterval(900)) == 0)
    }

    @Test("Duration labels", arguments: [
        (600, "10 min"), (5400, "1 h 30 min"), (45, "45 s"), (3600, "1 h"), (630, "10 min 30 s"),
        (3661, "1 h 1 min 1 s"),
    ])
    func durationText(seconds: Int, text: String) {
        #expect(TimerText.durationText(seconds: seconds) == text)
    }

    // MARK: Board TimerUntil

    @Test("Board duration card: 06:42 left, ends 21:16 IST, bar 67% full")
    func boardDuration() {
        let card = TimerText.card(Self.standup(), now: Self.boardNow, display: Self.ist, displayIsPhone: true)
        #expect(card.title == "Standup prep")
        #expect(card.tag == "Duration · 10 min")
        #expect(card.remaining == "06:42")
        #expect(card.status == "Ends 21:16 IST")
        #expect(card.untilTime == nil)
        #expect(card.localLine == nil)
        #expect(card.notes.isEmpty)
        #expect(Self.standup().status(at: Self.boardNow) == .running)
        #expect(Self.standup().progress(at: Self.boardNow) == 0.67)
    }

    @Test("Board Until card: 02:00 UTC, 07:30 IST on this phone · Fri, 10:20:42 left")
    func boardUntil() {
        let timer = CountdownTimer.until(hour: 2, minute: 0, in: .utc, occurrence: .first,
                                         name: "Deploy window", now: Self.boardNow)
        #expect(timer.endDate == Self.utc("2026-10-16T02:00:00Z"))
        #expect(timer.progress(at: Self.boardNow) == nil)
        let card = TimerText.card(timer, now: Self.boardNow, display: Self.ist, displayIsPhone: true)
        #expect(card.title == "Deploy window")
        #expect(card.tag == "Until")
        #expect(card.remaining == "10:20:42")
        #expect(card.status == nil)
        #expect(card.untilTime == "02:00 UTC")
        #expect(card.localLine == "07:30 IST on this phone · Fri")
        #expect(card.notes.isEmpty)
    }

    @Test("Until line hidden when the target zone is the shown zone (UTC pill on)")
    func untilSameZone() {
        let timer = CountdownTimer.until(hour: 2, minute: 0, in: .utc, occurrence: .first, now: Self.boardNow)
        let card = TimerText.card(timer, now: Self.boardNow, display: .utc, displayIsPhone: false)
        #expect(card.localLine == nil)
        #expect(card.title == "02:00 UTC")
    }

    @Test("Until line in UTC mode drops 'on this phone' and keeps the weekday")
    func untilInUTCMode() {
        let timer = CountdownTimer.until(hour: 7, minute: 30, in: Self.ist, occurrence: .first, now: Self.boardNow)
        #expect(timer.endDate == Self.utc("2026-10-16T02:00:00Z"))
        let card = TimerText.card(timer, now: Self.boardNow, display: .utc, displayIsPhone: false)
        #expect(card.untilTime == "07:30 IST")
        #expect(card.localLine == "02:00 UTC · Fri")
    }

    // MARK: Gap / overlap (decision AM, spec §5.2)

    @Test("Until 02:30 New York on 8 Mar: skipped, ends 03:00 EDT = 07:00Z")
    func untilInGap() {
        let now = Self.utc("2026-03-08T05:00:00Z")    // 00:00 EST
        let timer = CountdownTimer.until(hour: 2, minute: 30, in: Self.ny, occurrence: .first, now: now)
        #expect(timer.endDate == Self.utc("2026-03-08T07:00:00Z"))
        let card = TimerText.card(timer, now: now, display: Self.ist, displayIsPhone: true)
        #expect(card.remaining == "02:00:00")
        #expect(card.untilTime == "03:00 EDT")
        #expect(card.localLine == "12:30 IST on this phone")
        #expect(card.notes == ["02:30 doesn't happen in New York on Sun 8 Mar; ends 03:00 EDT. Your scheduler may differ."])
    }

    @Test("Until 02:30 New York once the gap day's 03:00 has passed: next day, exact")
    func untilAfterGap() {
        let now = Self.utc("2026-03-08T07:00:00Z")
        let timer = CountdownTimer.until(hour: 2, minute: 30, in: Self.ny, occurrence: .first, now: now)
        #expect(timer.endDate == Self.utc("2026-03-09T06:30:00Z"))
        #expect(TimerText.card(timer, now: now, display: Self.ist, displayIsPhone: true).notes.isEmpty)
    }

    @Test("Until 01:30 New York on 1 Nov: First 05:30Z, Second 06:30Z")
    func untilRepeated() {
        let now = Self.utc("2026-11-01T04:00:00Z")    // 00:00 EDT
        let first = CountdownTimer.until(hour: 1, minute: 30, in: Self.ny, occurrence: .first, now: now)
        let second = CountdownTimer.until(hour: 1, minute: 30, in: Self.ny, occurrence: .second, now: now)
        #expect(first.endDate == Self.utc("2026-11-01T05:30:00Z"))
        #expect(second.endDate == Self.utc("2026-11-01T06:30:00Z"))
        let firstCard = TimerText.card(first, now: now, display: Self.ny, displayIsPhone: true)
        #expect(firstCard.untilTime == "01:30 EDT")
        #expect(firstCard.localLine == nil)
        #expect(firstCard.notes == ["01:30 happens twice in New York on Sun 1 Nov; using the first (EDT). Your scheduler may differ."])
        let secondCard = TimerText.card(second, now: now, display: Self.ny, displayIsPhone: true)
        #expect(secondCard.untilTime == "01:30 EST")
        #expect(secondCard.notes == ["01:30 happens twice in New York on Sun 1 Nov; using the second (EST)."])
    }

    @Test("Until 01:30 New York after the first 01:30 has passed: the second one")
    func untilFirstPassed() {
        let now = Self.utc("2026-11-01T05:45:00Z")    // 01:45 EDT
        let timer = CountdownTimer.until(hour: 1, minute: 30, in: Self.ny, occurrence: .first, now: now)
        #expect(timer.endDate == Self.utc("2026-11-01T06:30:00Z"))
        let card = TimerText.card(timer, now: now, display: Self.ny, displayIsPhone: true)
        #expect(card.notes == ["01:30 happens twice in New York on Sun 1 Nov; the first has passed, so this is the second (EST)."])
    }

    @Test("Sheet preview: ends Fri 07:30 IST · in 10 h 20 min")
    func untilPreview() {
        let preview = TimerText.untilPreview(hour: 2, minute: 0, in: .utc, occurrence: .first,
                                             now: Self.boardNow, display: Self.ist)
        #expect(preview.ends == "Ends Fri 07:30 IST · in 10 h 20 min")
        #expect(preview.isRepeated == false)
        #expect(preview.note == nil)
        let gap = TimerText.untilPreview(hour: 1, minute: 30, in: Self.ny, occurrence: .first,
                                         now: Self.utc("2026-11-01T04:00:00Z"), display: Self.ny)
        #expect(gap.ends == "Ends 01:30 EDT · in 1 h 30 min")
        #expect(gap.isRepeated)
    }

    // MARK: Pause, +1 min, restart (decision AJ)

    @Test("Pause keeps the remaining time; +1 min while paused; resume sets a new end")
    func pauseAddResume() {
        let start = Self.utc("2026-10-15T15:36:00Z")
        var timer = CountdownTimer.duration(seconds: 600, now: start)
        timer.pause(at: start.addingTimeInterval(198))
        let later = start.addingTimeInterval(500)
        #expect(timer.status(at: later) == .paused)
        #expect(timer.remainingSeconds(at: later) == 402)
        #expect(timer.endDate == nil)
        #expect(TimerText.card(timer, now: later, display: Self.ist, displayIsPhone: true).status == "Paused")
        timer.addMinute(at: later)
        #expect(timer.remainingSeconds(at: later) == 462)
        #expect(timer.progress(at: later) == 0.7)
        #expect(TimerText.card(timer, now: later, display: Self.ist, displayIsPhone: true).tag == "Duration · 11 min")
        timer.resume(at: start.addingTimeInterval(1000))
        #expect(timer.endDate == start.addingTimeInterval(1462))
        #expect(timer.status(at: start.addingTimeInterval(1000)) == .running)
    }

    @Test("+1 min while running moves the end by 60 s")
    func addMinuteRunning() {
        var timer = Self.standup()
        timer.addMinute(at: Self.boardNow)
        #expect(timer.endDate == Self.utc("2026-10-15T15:47:00Z"))
        #expect(timer.remainingSeconds(at: Self.boardNow) == 462)
    }

    @Test("Finished: Done card; restart uses the original length")
    func finishedAndRestart() {
        var timer = Self.standup()
        timer.addMinute(at: Self.boardNow)
        let after = Self.utc("2026-10-15T15:50:00Z")
        #expect(timer.status(at: after) == .finished)
        #expect(timer.progress(at: after) == 0)
        let card = TimerText.card(timer, now: after, display: Self.ist, displayIsPhone: true)
        #expect(card.remaining == "00:00")
        #expect(card.status == "Done · ended 21:17 IST")
        timer.restart(at: after)
        #expect(timer.endDate == after.addingTimeInterval(600))
        #expect(TimerText.card(timer, now: after, display: Self.ist, displayIsPhone: true).tag == "Duration · 10 min")
    }

    @Test("Until passed: Passed 10 min ago")
    func untilPassed() {
        let timer = CountdownTimer.until(hour: 2, minute: 0, in: .utc, occurrence: .first, now: Self.boardNow)
        let after = Self.utc("2026-10-16T02:10:00Z")
        #expect(timer.status(at: after) == .finished)
        let card = TimerText.card(timer, now: after, display: Self.ist, displayIsPhone: true)
        #expect(card.remaining == "00:00")
        #expect(card.status == "Passed 10 min ago")
    }

    // MARK: Ends line (decision AL, spec §5.3)

    @Test("Ends after the phone's clocks go back: GMT time and a note")
    func endsAcrossClockChange() {
        let start = Self.utc("2026-10-25T00:30:00Z")    // 01:30 BST
        let timer = CountdownTimer.duration(seconds: 7200, now: start)
        let card = TimerText.card(timer, now: start, display: Self.london, displayIsPhone: true)
        #expect(card.status == "Ends 02:30 GMT")
        #expect(card.notes == ["Clocks go back 1 hour at 02:00 BST before this ends."])
        let afterChange = Self.utc("2026-10-25T01:30:00Z")
        #expect(TimerText.card(timer, now: afterChange, display: Self.london, displayIsPhone: true).notes.isEmpty)
    }

    @Test("Ends tomorrow gets a weekday")
    func endsTomorrow() {
        let start = Self.utc("2026-10-15T18:00:00Z")    // 23:30 IST Thu
        let timer = CountdownTimer.duration(seconds: 3600, now: start)
        #expect(TimerText.card(timer, now: start, display: Self.ist, displayIsPhone: true).status == "Ends Fri 00:30 IST")
    }

    // MARK: List (decision AJ)

    @Test("Header counts running, paused and done")
    func header() {
        let running = Self.standup()
        var paused = Self.standup()
        paused.pause(at: Self.boardNow)
        let done = CountdownTimer.duration(seconds: 60, now: Self.utc("2026-10-15T15:00:00Z"))
        #expect(TimerText.header([running, running], now: Self.boardNow) == "2 running")
        #expect(TimerText.header([running, paused, done], now: Self.boardNow) == "1 running · 1 paused · 1 done")
        #expect(TimerText.header([], now: Self.boardNow) == nil)
    }

    @Test("Order: done first, then running by end, then paused by remaining")
    func order() {
        let now = Self.boardNow
        let done = CountdownTimer.duration(seconds: 60, name: "done", now: now.addingTimeInterval(-120))
        let soon = CountdownTimer.duration(seconds: 120, name: "soon", now: now)
        let late = CountdownTimer.duration(seconds: 900, name: "late", now: now)
        var shortPause = CountdownTimer.duration(seconds: 30, name: "shortPause", now: now)
        shortPause.pause(at: now)
        var longPause = CountdownTimer.duration(seconds: 3000, name: "longPause", now: now)
        longPause.pause(at: now)
        let sorted = TimerText.sorted([longPause, late, shortPause, soon, done], now: now)
        #expect(sorted.map(\.name) == ["done", "soon", "late", "shortPause", "longPause"])
    }

    @Test("Codable round trip keeps every field")
    func codable() throws {
        var paused = Self.standup()
        paused.pause(at: Self.boardNow)
        let until = CountdownTimer.until(hour: 1, minute: 30, in: Self.ny, occurrence: .second,
                                         now: Self.utc("2026-11-01T04:00:00Z"))
        for timer in [Self.standup(), paused, until] {
            let data = try JSONEncoder().encode(timer)
            #expect(try JSONDecoder().decode(CountdownTimer.self, from: data) == timer)
        }
    }
}
