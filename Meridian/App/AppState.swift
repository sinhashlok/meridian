import Observation

/// App-wide UI state shared by every tab through the environment.
/// In-memory for M0; moves to App Group UserDefaults in M8 so widgets can read
/// the UTC display setting (spec §6).
@Observable final class AppState {
    /// UTC pill flipped on: every displayed time is shown in UTC (spec §4.1).
    var isUTCMode = false
    var isSettingsPresented = false
}
