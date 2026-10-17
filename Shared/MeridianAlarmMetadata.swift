import AlarmKit

/// AlarmKit requires a metadata type even when there is nothing to attach. Compiled into
/// both targets: the widget draws the snooze countdown for `AlarmAttributes` of this
/// type (decision BG), and ActivityKit matches the two sides by type.
/// `nonisolated` keeps it off the MainActor so it can be `Sendable`, as AlarmKit requires.
nonisolated struct MeridianAlarmMetadata: AlarmMetadata {}
