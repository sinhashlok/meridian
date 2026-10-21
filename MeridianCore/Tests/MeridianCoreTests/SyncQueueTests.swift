import Testing
@testable import MeridianCore

/// The alarm and reminder syncs: never two at once, and a burst of taps (five quick
/// "+1 min") costs at most one extra sync, which does the latest request.
@Suite("Sync queue")
@MainActor
struct SyncQueueTests {
    /// Holds a run at `wait()` until the test calls `open()`.
    @MainActor final class Gate {
        private var continuation: CheckedContinuation<Void, Never>?
        private var isOpen = false

        func wait() async {
            if isOpen { return }
            await withCheckedContinuation { continuation = $0 }
        }

        func open() {
            isOpen = true
            continuation?.resume()
            continuation = nil
        }
    }

    /// What ran, in order, and how many runs were ever in progress at once.
    @MainActor final class Log {
        var finished: [String] = []
        var started: [String] = []
        var active = 0
        var maxActive = 0

        func work(_ name: String, gate: Gate? = nil) -> @MainActor () async -> Void {
            { [self] in
                started.append(name)
                active += 1
                maxActive = max(maxActive, active)
                await gate?.wait()
                await Task.yield()
                active -= 1
                finished.append(name)
            }
        }

        func waitUntilStarted(_ name: String) async {
            while !started.contains(name) { await Task.yield() }
        }
    }

    @Test("An idle queue runs each request")
    func idle() async {
        let queue = SyncQueue(), log = Log()
        await queue.enqueue(log.work("A")).value
        await queue.enqueue(log.work("B")).value
        #expect(log.finished == ["A", "B"])
    }

    @Test("A burst during a run adds one run, which does the latest request")
    func burst() async {
        let queue = SyncQueue(), log = Log(), gate = Gate()
        let first = queue.enqueue(log.work("A", gate: gate))
        await log.waitUntilStarted("A")
        let later = ["B", "C", "D", "E", "F"].map { queue.enqueue(log.work($0)) }
        gate.open()
        await first.value
        for task in later { await task.value }
        #expect(log.finished == ["A", "F"])
        #expect(log.maxActive == 1)
    }

    @Test("Each caller's task ends after a run that started after its call")
    func awaitingMeansSynced() async {
        let queue = SyncQueue(), log = Log(), gate = Gate()
        queue.enqueue(log.work("A", gate: gate))
        await log.waitUntilStarted("A")
        let b = queue.enqueue(log.work("B"))
        queue.enqueue(log.work("C"))
        gate.open()
        await b.value
        #expect(log.finished == ["A", "C"])     // C's run also covers B's request
    }

    @Test("A request during the follow-up run gets a run of its own")
    func requestDuringFollowUp() async {
        let queue = SyncQueue(), log = Log(), gateA = Gate(), gateB = Gate()
        queue.enqueue(log.work("A", gate: gateA))
        await log.waitUntilStarted("A")
        queue.enqueue(log.work("B", gate: gateB))
        gateA.open()
        await log.waitUntilStarted("B")
        let c = queue.enqueue(log.work("C"))
        gateB.open()
        await c.value
        #expect(log.finished == ["A", "B", "C"])
        #expect(log.maxActive == 1)
    }
}
