import MeridianCore
import SwiftData
import SwiftUI
import UIKit  // UIApplication.openSettingsURLString

/// Alarms › Jobs (spec §4.3, boards JobsList, JobsNotifOff, JobsEmpty): a schedule book,
/// grouped Next 24 hours / Later / Paused. No status, no last run, no colour dots.
struct JobsView: View {
    @Query(sort: \SavedJob.order) private var saved: [SavedJob]
    @Query(sort: \SavedZone.order) private var zones: [SavedZone]
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    @State private var isAdding = false
    @State private var showsChanges = false

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let now = appState.now(timeline.date)
            let device = Zone.device
            let display: Zone = appState.isUTCMode ? .utc : device
            let jobs = JobStore.jobs(from: saved).map(\.job)

            if jobs.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        ActionHeader(JobText.header(count: jobs.count, display: display, now: now),
                                     buttonTitle: "New job") { isAdding = true }
                        if JobReminders.shared.notificationsDenied, let detail = JobText.notificationsOffDetail(jobs) {
                            InlineBanner(title: "Notifications are off", detail: detail, systemImage: "bell.slash",
                                         action: ("Turn on", turnOn))
                        }
                        ForEach(JobText.groups(jobs, now: now), id: \.group) { group in
                            Text(group.group.title.uppercased())
                                .meridianFont(.caption).bold()
                                .tracking(0.6)
                                .foregroundStyle(.textSecondary)
                                .padding(.top, Spacing.xs)
                                .padding(.leading, Spacing.xs)
                                .accessibilityAddTraits(.isHeader)
                            ToolCard {
                                ForEach(group.jobs) { job in
                                    NavigationLink(value: job.id) {
                                        JobRow(job: job, text: JobText.row(job, now: now, display: display, device: device),
                                               notificationsDenied: JobReminders.shared.notificationsDenied,
                                               onBadge: { showsChanges = true })
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.screenMargin)
                    .padding(.bottom, Spacing.sectionGap)
                }
            }
        }
        .navigationDestination(for: UUID.self) { id in
            Text(saved.first { $0.job?.id == id }?.job?.title ?? "")
        }
        .sheet(isPresented: $isAdding) {
            Text("New job")
        }
        .sheet(isPresented: $showsChanges) {
            UpcomingChangesSheet(zones: zones, alsoUsed: jobZones)
        }
        .onAppear {
            JobStore.applyDebugLaunch(saved, in: context)
            if DebugLaunch.jobs != nil { JobReminders.shared.sync(in: context) }
        }
    }

    /// Board JobsEmpty: what Jobs is for, and the one orange button.
    private var emptyState: some View {
        VStack(spacing: Spacing.m) {
            Text("No jobs yet")
                .meridianFont(.title)
                .foregroundStyle(.textPrimary)
            Text("Note when your pipelines, notebooks and refreshes should run. Jobs never connect to your scheduler.")
                .meridianFont(.body)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
            Button { isAdding = true } label: {
                Label("New job", systemImage: "plus")
                    .meridianFont(.headline)
                    .foregroundStyle(.onAccent)
                    .padding(.horizontal, Spacing.xl)
                    .frame(minHeight: Spacing.minTapTarget + Spacing.xs)
                    .background(.accent, in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Zones of jobs, for Upcoming clock changes.
    private var jobZones: [(zone: Zone, name: String)] {
        Array(Set(JobStore.jobs(from: saved).map(\.job.zone))).map { ($0, ZoneCatalog.displayName(for: $0)) }
    }

    /// Asks if never asked; once denied, only Settings can turn notifications back on.
    private func turnOn() {
        Task {
            if !(await JobReminders.shared.requestPermission(in: context)) {
                openURL(URL(string: UIApplication.openSettingsURLString)!)
            }
        }
    }
}
