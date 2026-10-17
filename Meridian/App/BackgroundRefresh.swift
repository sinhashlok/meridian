import BackgroundTasks
import Foundation
import SwiftData

/// Background app refresh (M7 step 9): refills zoned alarms' 14 days of fixed rings
/// (decision BD) and the 48-hour job reminder window (decision BK) when the app hasn't been
/// opened. iOS decides when it actually runs; launch and `.active` still sync too.
@MainActor enum BackgroundRefresh {
    /// Listed under `BGTaskSchedulerPermittedIdentifiers` in `Config/Meridian-Info.plist`.
    static let identifier = "com.shloksinha.meridian.refresh"

    /// Asks iOS for the next refresh, no sooner than in 4 hours. Called whenever the app
    /// goes to the background and after each refresh.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date.now.addingTimeInterval(4 * 3600)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Background refresh not scheduled: \(error)")
        }
    }

    /// The refresh itself: queue the next one, then run both syncs to completion.
    static func run() async {
        schedule()
        let context = AppModel.container.mainContext
        await ClockAlarms.shared.sync(in: context).value
        await JobReminders.shared.sync(in: context).value
    }
}
