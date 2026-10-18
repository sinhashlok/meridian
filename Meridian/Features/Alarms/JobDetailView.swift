import MeridianCore
import SwiftData
import SwiftUI

/// Job detail (spec §4.3, boards JobDetail and JobDetailScrolled): category and title,
/// the review banner, the schedule in the job's zone with its next run, the next 5 runs,
/// children "expected at", Mirrors, Last reviewed, Remind me, Pause and Delete.
/// No status and no last run anywhere (principle 4).
struct JobDetailView: View {
    let row: SavedJob

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var reviewed = 0
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// `Motion.stateChange`, or none under Reduce Motion (rows and fields move).
    private var stateChange: Animation? { Motion.moving(Motion.stateChange, reduceMotion: reduceMotion) }

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let now = appState.now(timeline.date)
            if let job = row.job {
                content(job, now: now)
            }
        }
        .background(.bgBase)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .containerBackground(.bgBase, for: .navigation)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { UTCPill() }
                .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isEditing = true }
                    .tint(.textPrimary)
            }
        }
        .sheet(isPresented: $isEditing) {
            JobEditSheet(original: row.job) { job in
                JobStore.update(row) { $0 = job }
                JobReminders.shared.sync(in: context)
            }
        }
        .sensoryFeedback(Haptic.success, trigger: reviewed)
        .onAppear {
            if DebugLaunch.screen == "jobEdit" || DebugLaunch.screen == "jobEditCron" { isEditing = true }
        }
    }

    private func content(_ job: Job, now: Date) -> some View {
        let device = Zone.device
        let display: Zone = appState.isUTCMode ? .utc : device
        let today = ZoneClock.local(now, in: device).date
        let card = JobText.scheduleCard(job, now: now, display: display, device: device)
        let runs = job.nextRuns(after: now, count: 5)

        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    caption(job.category.title)
                    Text(job.title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if !job.notes.isEmpty {
                        Text(job.notes)
                            .meridianFont(.body)
                            .foregroundStyle(.textSecondary)
                    }
                }
                if let banner = JobText.reviewBanner(job, today: today) {
                    InlineBanner(title: "Check this still matches the real scheduler", detail: banner,
                                 systemImage: "calendar.badge.checkmark",
                                 action: ("Mark reviewed", { markReviewed(now: now) }))
                }
                scheduleCard(card, isPaused: job.isPaused)
                ForEach(ScheduleEngine.warnings(job.schedule, in: job.zone, runs: runs), id: \.message) { warning in
                    NoteLine(systemImage: "clock.arrow.circlepath", text: warning.message)
                }
                if !runs.isEmpty {
                    caption("Next \(runs.count) runs").padding(.top, Spacing.xs)
                    RunTable(runs: runs, now: now)
                }
                if !job.children.isEmpty { children(job, now: now, display: display) }
                mirrorsCard(job, today: today, now: now)
                settingsCard(job)
                deleteButton
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.bottom, Spacing.sectionGap)
        }
        .defaultScrollAnchor(DebugLaunch.startsAtBottom ? .bottom : .top)
    }

    // MARK: Parts

    private func caption(_ text: String) -> some View {
        Text(text.uppercased())
            .meridianFont(.caption).bold()
            .tracking(0.6)
            .foregroundStyle(.textSecondary)
    }

    private func scheduleCard(_ card: JobScheduleCard, isPaused: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Schedule").meridianFont(.sub).foregroundStyle(.textSecondary)
            Text(card.title)
                .meridianFont(.title)
                .monospacedDigit()
                .foregroundStyle(.textPrimary)
            if let phone = card.phoneLine {
                Text(phone).meridianFont(.body).monospacedDigit().foregroundStyle(.textSecondary)
            }
            Rectangle().fill(Color.separatorLine).frame(height: 1).padding(.vertical, Spacing.xxs)
            // Not RowOrStack: the value's lines align trailing in a row and leading when
            // stacked. AnyLayout keeps the same views either way (see RowOrStack).
            let stacked = typeSize.isAccessibilitySize
            let layout = stacked
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xxs))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            layout {
                Text("Next run").meridianFont(.body).foregroundStyle(.textPrimary)
                if !stacked { Spacer(minLength: Spacing.s) }
                nextRun(card, isPaused: isPaused, alignment: stacked ? .leading : .trailing)
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bgSurface, in: .rect(cornerRadius: Radius.card, style: .continuous))
    }

    @ViewBuilder
    private func nextRun(_ card: JobScheduleCard, isPaused: Bool, alignment: HorizontalAlignment) -> some View {
        if isPaused {
            Label("Paused", systemImage: "pause.fill").meridianFont(.body).foregroundStyle(.textSecondary)
        } else if let next = card.nextRun {
            VStack(alignment: alignment, spacing: 2) {
                Text(next).meridianFont(.monoBody).foregroundStyle(.textPrimary)
                if let countdown = card.countdown {
                    // Orange only within 24 hours (spec §3.2).
                    Label(countdown, systemImage: "clock")
                        .meridianFont(.sub)
                        .foregroundStyle(card.countdownIsSoon ? Color.accentText : .textSecondary)
                }
            }
        } else {
            Text("Never runs").meridianFont(.body).foregroundStyle(.textSecondary)
        }
    }

    /// One child per row: offset, name, expected time in one aligned column.
    private func children(_ job: Job, now: Date, display: Zone) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            caption(JobText.childrenHeader(job)).padding(.top, Spacing.xs)
            // One aligned grid, so every row wraps the same way; stacked rows only at
            // accessibility sizes.
            Grid(alignment: .leading, horizontalSpacing: Spacing.s, verticalSpacing: 0) {
                ForEach(Array(JobText.childRows(job, now: now, display: display).enumerated()), id: \.offset) { index, child in
                    if index > 0 {
                        Rectangle().fill(Color.separatorLine).frame(height: 1).gridCellUnsizedAxes(.horizontal)
                    }
                    if typeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(child.name).meridianFont(.body).foregroundStyle(.textPrimary)
                            Text("\(child.offset) · \(child.expected ?? "")")
                                .meridianFont(.monoBody).foregroundStyle(.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: Spacing.minRowHeight, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    } else {
                        GridRow {
                            Text(child.offset).meridianFont(.monoBody).foregroundStyle(.textSecondary)
                            Text(child.name).meridianFont(.body).foregroundStyle(.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(child.expected ?? "").meridianFont(.monoBody).foregroundStyle(.textPrimary)
                                .fixedSize()
                        }
                        .frame(minHeight: Spacing.minRowHeight)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(.horizontal, Spacing.m)
            .background(.bgSurface, in: .rect(cornerRadius: Radius.card, style: .continuous))
            Text("Offsets are elapsed time from the parent's start. They show when each step is expected, "
                 + "not whether it ran.")
                .meridianFont(.sub)
                .foregroundStyle(.textSecondary)
                .padding(.horizontal, Spacing.xs)
        }
    }

    private func mirrorsCard(_ job: Job, today: CivilDate, now: Date) -> some View {
        ToolCard {
            if !job.mirrors.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mirrors").meridianFont(.sub).foregroundStyle(.textSecondary)
                    Text(job.mirrors).meridianFont(.monoBody).foregroundStyle(.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.m)
            }
            // The text wraps beside the button (board JobDetailScrolled); stacked at
            // accessibility sizes.
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        reviewedText(job, today: today)
                        markReviewedButton(now: now)
                    }
                } else {
                    HStack(spacing: Spacing.s) {
                        reviewedText(job, today: today)
                        Spacer(minLength: 0)
                        markReviewedButton(now: now).fixedSize()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.m)
        }
    }

    private func reviewedText(_ job: Job, today: CivilDate) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Last reviewed").meridianFont(.sub).foregroundStyle(.textSecondary)
            Text(JobText.reviewedLine(job, today: today)).meridianFont(.body).foregroundStyle(.textPrimary)
        }
    }

    /// Outlined, not orange: the screen has no filled primary action (§3.2).
    private func markReviewedButton(now: Date) -> some View {
        Button { markReviewed(now: now) } label: {
            Text("Mark reviewed")
                .meridianFont(.headline)
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, Spacing.m)
                .frame(minHeight: Spacing.minTapTarget)
                .overlay { Capsule().strokeBorder(Color.fillControl, lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private func settingsCard(_ job: Job) -> some View {
        ToolCard {
            toggleRow("Remind me", detail: "A notification before each run", isOn: job.remindsMe) { isOn in
                change { $0.remindsMe = isOn }
            }
            if job.remindsMe {
                // Stacked at accessibility sizes so the value never breaks mid-word.
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
                    : AnyLayout(HStackLayout(spacing: Spacing.s))
                layout {
                    Text("Lead time").meridianFont(.body).foregroundStyle(.textPrimary)
                    if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                    Menu {
                        Picker("Lead time", selection: Binding(get: { job.reminderLeadMinutes },
                                                               set: { lead in change { $0.reminderLeadMinutes = lead } })) {
                            ForEach(Job.leadChoices, id: \.self) { Text(JobText.leadText($0)).tag($0) }
                        }
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Text(JobText.leadText(job.reminderLeadMinutes))
                            Image(systemName: "chevron.down").imageScale(.small)
                        }
                        .fixedSize()
                    }
                    .buttonStyle(.pill)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.xs)
                .frame(minHeight: Spacing.minRowHeight)
            }
            toggleRow("Pause job", detail: "Keeps the schedule. Hides upcoming runs and stops reminders.",
                      isOn: job.isPaused) { isOn in
                change { $0.isPaused = isOn }
            }
        }
    }

    private func toggleRow(_ title: String, detail: String, isOn: Bool, set: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(get: { isOn }, set: set)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).meridianFont(.body).foregroundStyle(.textPrimary)
                Text(detail).meridianFont(.sub).foregroundStyle(.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(minHeight: Spacing.minRowHeight)
    }

    /// Destructive, so `statusDanger` with a symbol, and confirmed first.
    private var deleteButton: some View {
        Button(role: .destructive) { isConfirmingDelete = true } label: {
            Label("Delete job", systemImage: "trash")
                .meridianFont(.headline)
                .foregroundStyle(.statusDanger)
                .frame(maxWidth: .infinity, minHeight: Spacing.minRowHeight)
                .background(.bgSurface, in: .rect(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, Spacing.xs)
        .confirmationDialog("Delete \(row.job?.title ?? "this job")?", isPresented: $isConfirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete job", role: .destructive) {
                JobStore.delete(row, in: context)
                JobReminders.shared.sync(in: context)
                dismiss()
            }
        } message: {
            Text("Its reminders stop. Your real scheduler isn't touched.")
        }
    }

    private func change(_ edit: (inout Job) -> Void) {
        withAnimation(stateChange) { JobStore.update(row, edit) }
        JobReminders.shared.sync(in: context)
    }

    private func markReviewed(now: Date) {
        withAnimation(stateChange) { JobStore.markReviewed(row, now: now) }
        reviewed += 1
    }
}
