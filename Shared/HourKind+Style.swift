import MeridianCore
import SwiftUI

/// How the Planner and its widget draw an hour kind. In Shared/ so both targets use it.
extension HourKind {
    /// Height first, colour second (CLAUDE.md UI rules).
    var barHeight: CGFloat {
        switch self {
        case .work: 26
        case .stretch: 16
        case .sleep: 4
        }
    }

    var color: Color {
        switch self {
        case .work: .accent
        case .stretch: .tintStretch
        case .sleep: .tintSleep
        }
    }
}
