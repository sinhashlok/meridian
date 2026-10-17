import MeridianCore
import SwiftUI

/// A native time picker for a wall-clock `ClockTime` (no date, no zone).
/// It edits a fixed reference date shown in UTC, so the device's zone can't shift the
/// value; the date maths lives in Core (`ClockTime.referenceDate`).
struct ClockTimePicker: View {
    let title: String
    @Binding var time: ClockTime

    var body: some View {
        DatePicker(title, selection: Binding(get: { time.referenceDate }, set: { time = ClockTime(referenceDate: $0) }),
                   displayedComponents: .hourAndMinute)
            .environment(\.timeZone, Zone.utc.foundationTimeZone)
    }
}

/// Seven day toggles, starting on `first` (Settings › Week start). On = accent fill with `onAccent` label (an active
/// state, §3.2); off = control outline. Wraps at large text sizes.
struct WeekdayPicker: View {
    @Binding var days: [Int]
    /// ISO weekday shown first (`AppState.firstWeekday`).
    var first = 1

    private static let letters = ["M", "T", "W", "T", "F", "S", "S"]
    private static let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                ForEach(Weekdays.ordered(from: first), id: \.self) { day in
                    toggle(day).frame(maxWidth: .infinity)
                }
            }
            FlowLayout(spacing: Spacing.xs) {
                ForEach(Weekdays.ordered(from: first), id: \.self, content: toggle)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }

    private func toggle(_ day: Int) -> some View {
        let isOn = days.contains(day)
        return Button {
            if isOn { days.removeAll { $0 == day } } else { days = (days + [day]).sorted() }
        } label: {
            Text(Self.letters[day - 1])
                .meridianFont(.headline)
                .foregroundStyle(isOn ? Color.onAccent : Color.textPrimary)
                .frame(minWidth: Spacing.minTapTarget, minHeight: Spacing.minTapTarget)
                .background(isOn ? Color.accent : Color.clear, in: .circle)
                .overlay { Circle().strokeBorder(isOn ? Color.clear : Color.fillControl, lineWidth: 1) }
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.names[day - 1])
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
