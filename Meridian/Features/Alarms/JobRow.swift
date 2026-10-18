import MeridianCore
import SwiftUI

/// One job (board JobsList): title with a bell when it reminds, the schedule line in the
/// job's zone with Review and DST tags, then `Next 21:30 IST today · in 28 min` (orange
/// within 24 hours) or `Paused`. Never a status (spec §4.3).
struct JobRow: View {
    let job: Job
    let text: JobRowText
    let notificationsDenied: Bool
    let onBadge: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                title
                FlowLayout(spacing: Spacing.xs) {
                    Text(text.scheduleLine)
                        .meridianFont(.sub)
                        .foregroundStyle(.textSecondary)
                    if text.needsReview { reviewTag }
                    if let badge = text.dstBadge { DSTBadge(text: badge, action: onBadge) }
                }
                if job.isPaused {
                    Label("Paused", systemImage: "pause.fill")
                        .meridianFont(.sub)
                        .foregroundStyle(.textSecondary)
                } else if let next = text.next {
                    nextLine(next)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .foregroundStyle(.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(minHeight: Spacing.minRowHeight)
        .contentShape(.rect)
    }

    private var title: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Text(job.title)
                .meridianFont(.headline)
                .foregroundStyle(job.isPaused ? Color.textSecondary : .textPrimary)
            if job.remindsMe, !job.isPaused {
                Image(systemName: notificationsDenied ? "bell.slash" : "bell")
                    .meridianFont(.caption)
                    .foregroundStyle(.textSecondary)
                    .accessibilityLabel(notificationsDenied ? "Reminder off: notifications are off" : "Reminds you")
            }
        }
    }

    /// `Next 21:30 IST today · ⏱ in 28 min`; the countdown is orange under 24 hours (§3.2).
    private func nextLine(_ next: String) -> some View {
        let countdown = text.countdown.map { countdown in
            Text(" · \(Image(systemName: "clock")) \(countdown)")
                .foregroundStyle(text.countdownIsSoon ? Color.accentText : .textSecondary)
        } ?? Text("")
        // Spoken without the glyph's name ("Clock in 28 min"); the audit read that longer
        // label as clipped text.
        return Text("\(Text(next).monospacedDigit().foregroundStyle(.textPrimary))\(countdown)")
            .meridianFont(.sub)
            .accessibilityLabel(text.countdown.map { "\(next), \($0)" } ?? next)
    }

    /// Neutral outlined tag (spec §4.3: "Review", never a status colour).
    private var reviewTag: some View {
        Text("Review")
            .meridianFont(.caption).bold()
            .foregroundStyle(.textPrimary)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .strokeBorder(Color.textSecondary, lineWidth: 1)
            }
            .fixedSize()
    }
}
