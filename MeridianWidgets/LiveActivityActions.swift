import Foundation

/// Widget-side stand-in for the app's `LiveActivityActions`. iOS runs Live Activity
/// intents in the app's process, so these are never called; they exist so the shared
/// intents compile here.
enum LiveActivityActions {
    static func session(_ action: LiveSessionAction) async {}
    static func timer(_ action: LiveTimerAction, id: UUID) async {}
}
