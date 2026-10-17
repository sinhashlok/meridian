import Foundation
import Testing
@testable import MeridianCore

/// Spec §4.4 stopwatch and decision AP.
@Suite("Stopwatch")
struct StopwatchTests {
    static let t0 = try! EpochParser.parseISO8601("2026-10-15T15:39:18Z").date

    static func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    /// Laps at 62.345 s, 120 s and 200.5 s.
    static func threeLaps() -> Stopwatch {
        var watch = Stopwatch()
        watch.start(at: at(0))
        watch.lap(at: at(62.345))
        watch.lap(at: at(120))
        watch.lap(at: at(200.5))
        return watch
    }

    @Test("MM:SS.cc under an hour, H:MM:SS.cc from an hour; centiseconds truncated", arguments: [
        (Int64(0), "00:00.00"), (62_345, "01:02.34"), (59_999, "00:59.99"), (3_599_999, "59:59.99"),
        (3_600_000, "1:00:00.00"), (3_723_450, "1:02:03.45"), (36_000_000, "10:00:00.00"),
    ])
    func format(ms: Int64, text: String) {
        #expect(StopwatchText.time(ms: ms) == text)
    }

    @Test("Stop keeps the elapsed time; start again adds to it")
    func stopAndResume() {
        var watch = Stopwatch()
        #expect(watch.elapsedMs(at: Self.at(5)) == 0)
        watch.start(at: Self.at(0))
        #expect(watch.isRunning)
        watch.stop(at: Self.at(10.5))
        #expect(!watch.isRunning)
        #expect(watch.elapsedMs(at: Self.at(20)) == 10_500)
        watch.start(at: Self.at(30))
        #expect(watch.elapsedMs(at: Self.at(31.25)) == 11_750)
    }

    @Test("Laps keep splits and totals in whole milliseconds")
    func laps() {
        let watch = Self.threeLaps()
        #expect(watch.laps == [
            Lap(number: 1, splitMs: 62_345, totalMs: 62_345),
            Lap(number: 2, splitMs: 57_655, totalMs: 120_000),
            Lap(number: 3, splitMs: 80_500, totalMs: 200_500),
        ])
        #expect(watch.currentLapMs(at: Self.at(210)) == 9_500)
    }

    @Test("Lap does nothing while stopped; reset clears everything")
    func lapWhenStoppedAndReset() {
        var watch = Self.threeLaps()
        watch.stop(at: Self.at(205))
        watch.lap(at: Self.at(206))
        #expect(watch.laps.count == 3)
        #expect(watch.currentLapMs(at: Self.at(300)) == 4_500)
        watch.reset()
        #expect(watch == Stopwatch())
        #expect(watch.elapsedMs(at: Self.at(400)) == 0)
    }

    @Test("Fastest and slowest are marked from 3 laps")
    func marks() {
        #expect(StopwatchText.marks(Self.threeLaps().laps) == [2: .fastest, 3: .slowest])
        var two = Stopwatch()
        two.start(at: Self.at(0))
        two.lap(at: Self.at(10))
        two.lap(at: Self.at(25))
        #expect(StopwatchText.marks(two.laps).isEmpty)
    }

    @Test("Ties mark the earliest lap; all equal marks none")
    func markTies() {
        func laps(_ splits: [Int64]) -> [Lap] {
            var total: Int64 = 0
            return splits.enumerated().map { index, split in
                total += split
                return Lap(number: index + 1, splitMs: split, totalMs: total)
            }
        }
        #expect(StopwatchText.marks(laps([5000, 5000, 7000, 7000])) == [1: .fastest, 3: .slowest])
        #expect(StopwatchText.marks(laps([5000, 5000, 5000])).isEmpty)
    }

    @Test("Copy CSV: header plus one row per completed lap")
    func csv() {
        #expect(StopwatchText.csv(Self.threeLaps().laps) == """
            lap,split_ms,total_ms,split,total
            1,62345,62345,01:02.34,01:02.34
            2,57655,120000,00:57.65,02:00.00
            3,80500,200500,01:20.50,03:20.50
            """)
    }

    @Test("Codable round trip, running and stopped")
    func codable() throws {
        var stopped = Self.threeLaps()
        stopped.stop(at: Self.at(250))
        for watch in [Self.threeLaps(), stopped] {
            let data = try JSONEncoder().encode(watch)
            #expect(try JSONDecoder().decode(Stopwatch.self, from: data) == watch)
        }
    }
}
