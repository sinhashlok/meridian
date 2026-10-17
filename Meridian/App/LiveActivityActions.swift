import Foundation
import MeridianCore
import SwiftData

/// What the Live Activity buttons do (decision BA), run in the app's process by iOS,
/// possibly with no window. Each change goes through the same store as the screens, then
/// waits for the alarms and the activity to catch up before returning: iOS may suspend
/// the app as soon as the intent finishes.
@MainActor enum LiveActivityActions {
    static func session(_ action: LiveSessionAction) async {
        let now = Date.now
        switch action {
        case .pause: SessionStore.update { $0.pause(at: now) }
        case .resume: SessionStore.update { $0.resume(at: now) }
        case .addFive: SessionStore.update { $0.addFiveMinutes(at: now) }
        case .skip: SessionStore.update { $0.skip(at: now) }
        case .stop: SessionStore.finish(at: now, in: AppModel.container.mainContext)
        }
        await SessionAlarms.shared.sync().value
    }

    static func timer(_ action: LiveTimerAction, id: UUID) async {
        let context = AppModel.container.mainContext
        let now = Date.now
        guard let row = TimerStore.timers(from: (try? context.fetch(FetchDescriptor<SavedTimer>())) ?? [])
            .first(where: { $0.timer.id == id })?.row else { return }
        switch action {
        case .pause: TimerStore.update(row) { $0.pause(at: now) }
        case .resume: TimerStore.update(row) { $0.resume(at: now) }
        case .addMinute: TimerStore.update(row) { $0.addMinute(at: now) }
        case .cancel: TimerStore.delete(row, in: context)
        }
        try? context.save()
        await TimerAlarms.shared.sync(in: context).value
    }
}
