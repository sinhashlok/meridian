/// Runs a sync job one at a time, collapsing a burst of requests into one more run.
///
/// The alarm and reminder syncs each re-read everything they need when they start, so
/// while one runs, any number of new requests can share a single follow-up run: it
/// starts when the current one finishes and does the most recently requested work.
/// (Like a job scheduler that keeps one run going and one queued, and drops the
/// duplicates in between.)
@MainActor public final class SyncQueue {
    /// The newest run: in progress, waiting its turn, or finished.
    private var latest: Task<Void, Never>?
    /// The run waiting for the current one to finish; new requests join it.
    private var waiting: Task<Void, Never>?
    /// The work the waiting run will do when it starts: the most recent request's.
    private var nextWork: (@MainActor () async -> Void)?

    public init() {}

    /// Queues `work`. The returned task finishes once a run that started after this call
    /// has finished, so awaiting it means "my change has been synced".
    @discardableResult
    public func enqueue(_ work: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        nextWork = work
        if let waiting { return waiting }

        let previous = latest
        let task = Task {
            await previous?.value
            // Started: requests from now on need a run after this one.
            waiting = nil
            let work = nextWork
            nextWork = nil
            await work?()
        }
        waiting = task
        latest = task
        return task
    }
}
