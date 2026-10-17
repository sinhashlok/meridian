import Foundation
import Testing
@testable import MeridianCore

/// Spec §4.5 Pomodoro and decisions AT–AX. Board Sessions is frozen at 2026-10-15T15:39:18Z
/// with Focus 1 of 4 started at 15:33:00Z. Values checked with Python `zoneinfo`.
@Suite("Sessions")
struct SessionTests {
    static let ist = Zone("Asia/Kolkata")!
    static let london = Zone("Europe/London")!

    static func utc(_ iso: String) -> Date { try! EpochParser.parseISO8601(iso).date }

    static let start = utc("2026-10-15T15:33:00Z")
    static let boardNow = utc("2026-10-15T15:39:18Z")

    static func board() -> PomodoroSession { .start(.standard, at: start) }

    // MARK: Phases (decisions AT, AU)

    @Test("25/5 × 4: 4 focus and 3 breaks, ending 17:28Z")
    func phases() {
        let session = Self.board()
        #expect(session.phases.map(\.kind) == [.focus, .rest, .focus, .rest, .focus, .rest, .focus])
        #expect(session.phases.map(\.cycle) == [1, 1, 2, 2, 3, 3, 4])
        #expect(session.phases[0].end == Self.utc("2026-10-15T15:58:00Z"))
        #expect(session.phases[1].start == Self.utc("2026-10-15T15:58:00Z"))
        #expect(session.phases[1].end == Self.utc("2026-10-15T16:03:00Z"))
        #expect(session.endDate == Self.utc("2026-10-15T17:28:00Z"))
    }

    @Test("One cycle is a single focus phase")
    func oneCycle() {
        let session = PomodoroSession.start(SessionLengths(focusMinutes: 50, breakMinutes: 10, cycles: 1), at: Self.start)
        #expect(session.phases.map(\.kind) == [.focus])
        #expect(session.endDate == Self.utc("2026-10-15T16:23:00Z"))
    }

    // MARK: Board Sessions

    @Test("Board: Focus · 1 of 4, 18:42 left, ends 21:28 IST, ring 74.8%")
    func board() {
        let session = Self.board()
        #expect(session.status(at: Self.boardNow) == .running(0))
        #expect(session.remainingSeconds(at: Self.boardNow) == 1122)
        #expect(session.fraction(at: Self.boardNow) == 0.748)
        let text = SessionText.card(session, now: Self.boardNow, display: Self.ist)
        #expect(text.phase == "Focus · 1 of 4")
        #expect(text.remaining == "18:42")
        #expect(text.status == "Ends 21:28 IST")
        #expect(text.dots == [.current, .upcoming, .upcoming, .upcoming])
        #expect(text.notes.isEmpty)
    }

    @Test("Break after focus 1: Break · 1 of 4, its cycle still current")
    func onBreak() {
        let now = Self.utc("2026-10-15T16:00:00Z")
        let session = Self.board()
        #expect(session.status(at: now) == .running(1))
        let text = SessionText.card(session, now: now, display: Self.ist)
        #expect(text.phase == "Break · 1 of 4")
        #expect(text.remaining == "03:00")
        #expect(text.status == "Ends 21:33 IST")
        #expect(text.dots == [.current, .upcoming, .upcoming, .upcoming])
    }

    @Test("Focus 3: earlier cycles done")
    func laterCycle() {
        let text = SessionText.card(Self.board(), now: Self.utc("2026-10-15T16:40:00Z"), display: Self.ist)
        #expect(text.phase == "Focus · 3 of 4")
        #expect(text.dots == [.done, .done, .current, .upcoming])
    }

    // MARK: Pause, +5 min, skip

    @Test("Pause freezes the time; resume shifts every later boundary by the pause")
    func pauseResume() {
        var session = Self.board()
        session.pause(at: Self.boardNow)
        let later = Self.utc("2026-10-15T15:45:00Z")
        #expect(session.status(at: later) == .paused(0))
        #expect(session.remainingSeconds(at: later) == 1122)
        let paused = SessionText.card(session, now: later, display: Self.ist)
        #expect(paused.status == "Paused")
        #expect(paused.remaining == "18:42")
        session.resume(at: Self.utc("2026-10-15T15:49:18Z"))
        #expect(session.status(at: Self.utc("2026-10-15T15:50:00Z")) == .running(0))
        #expect(session.phases[0].end == Self.utc("2026-10-15T16:08:00Z"))
        #expect(session.phases[1].start == Self.utc("2026-10-15T16:08:00Z"))
        #expect(session.endDate == Self.utc("2026-10-15T17:38:00Z"))
        #expect(session.fraction(at: Self.utc("2026-10-15T15:49:18Z")) == 0.748)
    }

    @Test("+5 min lengthens the current phase and moves the rest")
    func addFive() {
        var session = Self.board()
        session.addFiveMinutes(at: Self.boardNow)
        #expect(session.phases[0].end == Self.utc("2026-10-15T16:03:00Z"))
        #expect(session.remainingSeconds(at: Self.boardNow) == 1422)
        #expect(session.fraction(at: Self.boardNow) == 1422.0 / 1800)
        #expect(session.endDate == Self.utc("2026-10-15T17:33:00Z"))
    }

    @Test("Skip ends the phase now and pulls the rest earlier")
    func skip() {
        var session = Self.board()
        session.skip(at: Self.boardNow)
        #expect(session.phases[0].end == Self.boardNow)
        #expect(session.status(at: Self.boardNow) == .running(1))
        #expect(session.phases[1].end == Self.utc("2026-10-15T15:44:18Z"))
        #expect(session.endDate == Self.utc("2026-10-15T17:09:18Z"))
    }

    @Test("Done: summary counts real focus time (a skipped focus counts what was done)")
    func done() {
        let full = Self.board()
        #expect(full.status(at: Self.utc("2026-10-15T17:28:00Z")) == .done)
        #expect(SessionText.card(full, now: Self.utc("2026-10-15T17:30:00Z"), display: Self.ist).status
                == "Session done · 1 h 40 min focused")
        var skipped = Self.board()
        skipped.skip(at: Self.boardNow)
        let text = SessionText.card(skipped, now: Self.utc("2026-10-15T18:00:00Z"), display: Self.ist)
        #expect(text.status == "Session done · 1 h 21 min focused")
        #expect(text.remaining == "00:00")
        #expect(text.dots == [.done, .done, .done, .done])
    }

    // MARK: Alarms (decision AV)

    @Test("One alarm per remaining boundary, named for what comes next; none while paused")
    func alarms() {
        let alarms = Self.board().upcomingAlarms(at: Self.boardNow)
        #expect(alarms.map(\.fireDate) == ["15:58", "16:03", "16:28", "16:33", "16:58", "17:03", "17:28"]
            .map { Self.utc("2026-10-15T\($0):00Z") })
        #expect(alarms.map(\.title) == ["Break · 5 min", "Focus 2 of 4", "Break · 5 min", "Focus 3 of 4",
                                        "Break · 5 min", "Focus 4 of 4", "Session done"])
        #expect(Self.board().upcomingAlarms(at: Self.utc("2026-10-15T16:30:00Z")).count == 4)
        var paused = Self.board()
        paused.pause(at: Self.boardNow)
        #expect(paused.upcomingAlarms(at: Self.boardNow).isEmpty)
    }

    // MARK: Ends across a clock change (spec §5.3)

    @Test("Focus ending after the phone's clocks go back: GMT time and a note")
    func endsAcrossClockChange() {
        let session = PomodoroSession.start(.standard, at: Self.utc("2026-10-25T00:50:00Z"))    // 01:50 BST
        let text = SessionText.card(session, now: Self.utc("2026-10-25T00:50:00Z"), display: Self.london)
        #expect(text.status == "Ends 01:15 GMT")
        #expect(text.notes == ["Clocks go back 1 hour at 02:00 BST before this ends."])
    }

    // MARK: History (decision BB)

    @Test("Focus records so far, cut at now; a pause is not focus time")
    func focusRecords() {
        let session = Self.board()
        #expect(session.focusRecords(until: Self.utc("2026-10-15T16:10:00Z")) == [
            FocusRecord(interval: DateInterval(start: Self.start, end: Self.utc("2026-10-15T15:58:00Z")), seconds: 1500),
            FocusRecord(interval: DateInterval(start: Self.utc("2026-10-15T16:03:00Z"), end: Self.utc("2026-10-15T16:10:00Z")),
                        seconds: 420),
        ])
        var paused = Self.board()
        paused.pause(at: Self.boardNow)
        paused.resume(at: Self.utc("2026-10-15T15:49:18Z"))
        #expect(paused.focusRecords(until: Self.utc("2026-10-15T16:08:00Z")) == [
            FocusRecord(interval: DateInterval(start: Self.start, end: Self.utc("2026-10-15T16:08:00Z")), seconds: 1500),
        ])
        // Paused right now: the focus so far stops at the pause.
        var pausedNow = Self.board()
        pausedNow.pause(at: Self.boardNow)
        #expect(pausedNow.focusRecords(until: Self.utc("2026-10-15T15:45:00Z")) == [
            FocusRecord(interval: DateInterval(start: Self.start, end: Self.boardNow), seconds: 378),
        ])
    }

    @Test("Focused today counts only today's part in the shown zone")
    func todayTotal() {
        let records = [
            FocusRecord(interval: DateInterval(start: Self.utc("2026-10-15T18:20:00Z"), end: Self.utc("2026-10-15T18:45:00Z")),
                        seconds: 1500),
            FocusRecord(interval: DateInterval(start: Self.utc("2026-10-16T03:00:00Z"), end: Self.utc("2026-10-16T03:25:00Z")),
                        seconds: 1500),
        ]
        // IST midnight is 18:30Z, so 15 min of the first and all 25 of the second are on 16 Oct.
        #expect(SessionText.focusedToday(records, now: Self.utc("2026-10-16T05:00:00Z"), display: Self.ist)
                == "Focused today: 40 min")
        #expect(SessionText.focusedToday([], now: Self.boardNow, display: Self.ist) == nil)
    }

    @Test("Codable round trip, running and paused")
    func codable() throws {
        var paused = Self.board()
        paused.pause(at: Self.boardNow)
        for session in [Self.board(), paused] {
            #expect(try JSONDecoder().decode(PomodoroSession.self, from: JSONEncoder().encode(session)) == session)
        }
    }
}

/// Decision AZ: what the session Live Activity shows.
@Suite("Session Live Activity")
struct SessionActivityTests {
    static let ist = Zone("Asia/Kolkata")!
    static func utc(_ iso: String) -> Date { try! EpochParser.parseISO8601(iso).date }
    static let now = utc("2026-10-15T15:39:18Z")
    static let meeting = MeetingLine(title: "Best compromise in 21 min", detail: "16:00 UTC · 3 of 3 awake · Mumbai in stretch",
                                     start: utc("2026-10-15T16:00:00Z"), day: CivilDate(2026, 10, 15))

    @Test("Board LiveActivity: Focus · 1 of 4, ends 21:28 IST, counts down to 15:58Z, with the meeting line")
    func board() {
        let session = PomodoroSession.start(.standard, at: Self.utc("2026-10-15T15:33:00Z"))
        let content = SessionActivityContent.make(session, now: Self.now, display: Self.ist, meeting: Self.meeting)
        #expect(content == SessionActivityContent(
            phase: "Focus · 1 of 4", ends: "Ends 21:28 IST", isFocus: true,
            endDate: Self.utc("2026-10-15T15:58:00Z"), phaseStart: Self.utc("2026-10-15T15:33:00Z"),
            pausedRemaining: nil, pausedFraction: nil,
            meetingTitle: "Best compromise in 21 min", meetingDetail: "16:00 UTC · 3 of 3 awake · Mumbai in stretch"))
    }

    @Test("Paused: frozen time and ring, no countdown")
    func paused() {
        var session = PomodoroSession.start(.standard, at: Self.utc("2026-10-15T15:33:00Z"))
        session.pause(at: Self.now)
        let content = SessionActivityContent.make(session, now: Self.now, display: Self.ist, meeting: nil)
        #expect(content?.ends == "Paused")
        #expect(content?.endDate == nil)
        #expect(content?.pausedRemaining == "18:42")
        #expect(content?.pausedFraction == 0.748)
        #expect(content?.meetingTitle == nil)
    }

    @Test("A break counts down with the break's own start; done ends the activity")
    func breakAndDone() {
        let session = PomodoroSession.start(.standard, at: Self.utc("2026-10-15T15:33:00Z"))
        let onBreak = SessionActivityContent.make(session, now: Self.utc("2026-10-15T16:00:00Z"), display: Self.ist,
                                                  meeting: nil)
        #expect(onBreak?.isFocus == false)
        #expect(onBreak?.phaseStart == Self.utc("2026-10-15T15:58:00Z"))
        #expect(SessionActivityContent.make(session, now: Self.utc("2026-10-15T17:28:00Z"), display: Self.ist,
                                            meeting: nil) == nil)
    }
}
