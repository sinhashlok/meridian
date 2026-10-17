import MeridianCore
import SwiftData
import SwiftUI

/// The SchedulePicker presets (spec §4.3).
enum SchedulePreset: CaseIterable, Identifiable {
    case minutes, hours, daily, weekly, monthly, cron

    var id: Self { self }

    var title: String {
        switch self {
        case .minutes: "Every N min"
        case .hours: "Every N hours"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .cron: "Cron · Advanced"
        }
    }
}

/// What the SchedulePicker edits: every preset keeps its own fields, so switching presets
/// and back loses nothing. `schedule` builds Core's `Schedule` from the chosen one.
struct ScheduleDraft {
    var preset: SchedulePreset = .daily
    var minutes = 15
    var hours = 4
    var dailyTimes = [ClockTime(2, 0)]
    var weeklyDays: Set<Int> = [1, 2, 3, 4, 5]
    var weeklyTime = ClockTime(9, 0)
    /// 1…31, or 0 for the last day.
    var monthDay = 1
    var monthlyTime = ClockTime(1, 0)
    var isQuartz = false
    var cronText = "0 2 * * *"

    init(_ schedule: Schedule) {
        switch schedule {
        case .everyMinutes(let n): preset = .minutes; minutes = n
        case .everyHours(let n): preset = .hours; hours = n
        case .daily(let times): preset = .daily; dailyTimes = times
        case .weekly(let days, let time): preset = .weekly; weeklyDays = days; weeklyTime = time
        case .monthly(let day, let time):
            preset = .monthly
            monthlyTime = time
            if case .day(let number) = day { monthDay = number } else { monthDay = 0 }
        case .cron(let dialect, let text): preset = .cron; isQuartz = dialect == .quartz; cronText = text
        }
    }

    var schedule: Schedule {
        switch preset {
        case .minutes: .everyMinutes(minutes)
        case .hours: .everyHours(hours)
        case .daily: .daily(times: dailyTimes)
        case .weekly: .weekly(days: weeklyDays, time: weeklyTime)
        case .monthly: .monthly(day: monthDay == 0 ? .last : .day(monthDay), time: monthlyTime)
        case .cron: .cron(dialect: isQuartz ? .quartz : .unix, expression: cronText.trimmingCharacters(in: .whitespaces))
        }
    }
}

/// New / Edit job (spec §4.3, boards JobEdit and JobEditCron): title, description,
/// Mirrors, category, SchedulePicker, zone (UTC by default) with its time on this phone,
/// DST notes, and children with their expected offsets.
struct JobEditSheet: View {
    let original: Job?
    let onSave: (Job) -> Void

    @State private var job: Job
    @State private var draft: ScheduleDraft
    @State private var isPickingZone = false
    @State private var invalidSaves = 0
    /// Set by an invalid Save, so the missing title is pointed out.
    @State private var showsProblems = false

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// `Motion.stateChange`, or none under Reduce Motion (rows and fields move).
    private var stateChange: Animation? { Motion.moving(Motion.stateChange, reduceMotion: reduceMotion) }

    init(original: Job?, onSave: @escaping (Job) -> Void) {
        self.original = original
        self.onSave = onSave
        let start = original ?? Job(title: "", schedule: .daily(times: [ClockTime(2, 0)]),
                                    lastReviewed: ZoneClock.local(.now, in: .device).date)
        _job = State(initialValue: start)
        _draft = State(initialValue: ScheduleDraft(start.schedule))
    }

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { timeline in
                let now = appState.now(timeline.date)
                let candidate = edited
                let check = Result { () throws(ScheduleError) in
                    try ScheduleEngine.nextRuns(candidate.schedule, in: candidate.zone, after: now, count: 5)
                }

                Form {
                    Section {
                        // Wraps instead of truncating at large text sizes.
                        TextField("Netsuite pipeline run", text: $job.title, axis: .vertical)
                    } header: {
                        Text("Title")
                    } footer: {
                        if showsProblems, candidate.title.isEmpty {
                            Label("Add a title.", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.statusDanger)
                        }
                    }
                    Section("Description") {
                        TextField("What it does", text: $job.notes, axis: .vertical)
                            .lineLimit(2...5)
                    }
                    Section {
                        TextField("Airflow DAG netsuite_nightly", text: $job.mirrors, axis: .vertical)
                            .meridianFont(.monoBody)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                        Text("Mirrors · optional")
                    } footer: {
                        Text("Where the real schedule lives. For your reference only, not synced.")
                    }
                    Section {
                        Picker("Category", selection: $job.category) {
                            ForEach(Job.Category.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                    }

                    scheduleSection(check: check)
                    zoneSection(candidate, check: check, now: now)
                    if draft.preset == .cron, case .success(let runs) = check, !runs.isEmpty {
                        Section("Next \(runs.count) runs") {
                            RunTable(runs: runs, now: now)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                    }
                    childrenSection
                }
                .scrollContentBackground(.hidden)
                // Always editing: children show visible delete and drag handles (board
                // JobEdit's ≡), never swipe-only (spec principle 1).
                .environment(\.editMode, .constant(.active))
            }
            // Pickers and Cancel are not "on" states: neutral, not orange (spec §3.2).
            .tint(.textPrimary)
            .navigationTitle(original == nil ? "New job" : "Edit job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    // The sheet's one filled orange button (spec §3.2).
                    Button("Save", action: save)
                        .buttonStyle(.borderedProminent)
                        .tint(.accent)
                        .foregroundStyle(.onAccent)
                }
            }
        }
        .presentationBackground(.bgElevated)
        .sensoryFeedback(Haptic.warning, trigger: invalidSaves)
        .sheet(isPresented: $isPickingZone) {
            ZonePickerSheet(title: "Time zone", allowsLocal: false, selected: job.zoneID) { zone in
                if let zone { job.zoneID = zone.id }
            }
        }
        .onAppear {
            // Debug: board JobEditCron shows the month-end job as its cron expression.
            if DebugLaunch.screen == "jobEditCron" {
                draft.preset = .cron
                draft.cronText = "0 1 1 * *"
            }
        }
    }

    /// The job as Save would store it.
    private var edited: Job {
        var copy = job
        copy.title = job.title.trimmingCharacters(in: .whitespaces)
        copy.schedule = draft.schedule
        return copy
    }

    // MARK: Schedule

    private func scheduleSection(check: Result<[ScheduledRun], ScheduleError>) -> some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(SchedulePreset.allCases) { preset in chip(preset) }
                }
                .padding(.vertical, Spacing.xxs)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .defaultScrollAnchor(draft.preset == .cron ? .trailing : .leading)

            presetControls
        } header: {
            Text("Schedule")
        } footer: {
            if case .failure(let error) = check {
                Label(JobText.scheduleProblem(error), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.statusDanger)
            } else if draft.preset == .cron,
                      let expression = try? CronExpression.parse(draft.cronText, dialect: draft.isQuartz ? .quartz : .unix) {
                Text(expression.description)
                    .meridianFont(.headline)
                    .foregroundStyle(.textPrimary)
            }
        }
    }

    /// Selected = outlined in `textPrimary`; a choice, not an "on" state, so never orange.
    private func chip(_ preset: SchedulePreset) -> some View {
        let isSelected = draft.preset == preset
        return Button { withAnimation(stateChange) { draft.preset = preset } } label: {
            Text(preset.title)
                .meridianFont(isSelected ? .headline : .body)
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, Spacing.m)
                .frame(minHeight: Spacing.minTapTarget)
                .background(Color.bgSurface, in: .capsule)
                .overlay {
                    Capsule().strokeBorder(isSelected ? Color.textPrimary : .separatorLine, lineWidth: isSelected ? 1.5 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var presetControls: some View {
        switch draft.preset {
        case .minutes:
            Picker("Every", selection: $draft.minutes) {
                ForEach(ScheduleEngine.minuteIntervals, id: \.self) { Text("\($0) min").tag($0) }
            }
        case .hours:
            Picker("Every", selection: $draft.hours) {
                ForEach(ScheduleEngine.hourIntervals, id: \.self) { Text("\($0) hour\($0 == 1 ? "" : "s")").tag($0) }
            }
        case .daily:
            ForEach(draft.dailyTimes.indices, id: \.self) { index in
                HStack {
                    ClockTimePicker(title: index == 0 ? "At" : "And", time: $draft.dailyTimes[index])
                    if draft.dailyTimes.count > 1 {
                        Button("Remove time", systemImage: "minus.circle") { draft.dailyTimes.remove(at: index) }
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.textSecondary)
                            .frame(minWidth: Spacing.minTapTarget, minHeight: Spacing.minTapTarget)
                    }
                }
            }
            Button("Time", systemImage: "plus") {
                draft.dailyTimes.append(ClockTime(((draft.dailyTimes.last?.hour ?? 1) + 1) % 24, 0))
            }
        case .weekly:
            WeekdayPicker(days: Binding(get: { draft.weeklyDays.sorted() }, set: { draft.weeklyDays = Set($0) }),
                          first: appState.firstWeekday)
            ClockTimePicker(title: "At", time: $draft.weeklyTime)
        case .monthly:
            Picker("Day", selection: $draft.monthDay) {
                ForEach(1...31, id: \.self) { Text("Day \($0)").tag($0) }
                Text("Last day").tag(0)
            }
            ClockTimePicker(title: "At", time: $draft.monthlyTime)
        case .cron:
            Picker("Dialect", selection: $draft.isQuartz) {
                Text("Unix 5-field").tag(false)
                Text("Quartz 6/7-field").tag(true)
            }
            TextField(draft.isQuartz ? "0 0 2 ? * MON-FRI" : "0 2 * * *", text: $draft.cronText)
                .meridianFont(.monoTime)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
        }
    }

    // MARK: Zone

    private func zoneSection(_ candidate: Job, check: Result<[ScheduledRun], ScheduleError>, now: Date) -> some View {
        Section {
            LabeledContent("Time zone") {
                Button { isPickingZone = true } label: {
                    HStack(spacing: Spacing.xxs) {
                        Text(ZoneCatalog.displayName(for: candidate.zone))
                        Image(systemName: "chevron.right").imageScale(.small)
                    }
                }
                .buttonStyle(.pill)
            }
        } footer: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(JobText.zoneLine(candidate.zone, now: now))
                    .meridianFont(.sub)
                    .foregroundStyle(.textSecondary)
                if let preview = JobText.editPreview(candidate, now: now, device: .device) {
                    Text(preview).meridianFont(.sub).foregroundStyle(.textSecondary)
                }
                if case .success(let runs) = check {
                    ForEach(ScheduleEngine.warnings(candidate.schedule, in: candidate.zone, runs: runs), id: \.message) {
                        NoteLine(systemImage: "clock.arrow.circlepath", text: $0.message, inset: 0)
                    }
                }
            }
            .padding(.top, Spacing.xxs)
        }
    }

    // MARK: Children

    private var childrenSection: some View {
        Section {
            ForEach($job.children) { $child in
                HStack(spacing: Spacing.s) {
                    offsetMenu($child.offsetMinutes)
                    TextField("Step name", text: $child.name)
                }
            }
            .onMove { job.children.move(fromOffsets: $0, toOffset: $1) }
            .onDelete { job.children.remove(atOffsets: $0) }
            Button("Add child", systemImage: "plus") {
                job.children.append(Job.Child(name: "", offsetMinutes: (job.children.last?.offsetMinutes ?? -15) + 15))
            }
        } header: {
            Text("Children · expected offset from start")
        } footer: {
            Text("Elapsed time from the parent's start. Drag ≡ to reorder.")
        }
    }

    /// `+0:45`: hours and minutes since the parent's start (decision BM).
    private func offsetMenu(_ minutes: Binding<Int>) -> some View {
        Menu {
            Picker("Hours", selection: Binding(get: { minutes.wrappedValue / 60 },
                                               set: { minutes.wrappedValue = $0 * 60 + minutes.wrappedValue % 60 })) {
                ForEach(0..<24, id: \.self) { Text("\($0) h").tag($0) }
            }
            Picker("Minutes", selection: Binding(get: { minutes.wrappedValue % 60 / 5 * 5 },
                                                 set: { minutes.wrappedValue = minutes.wrappedValue / 60 * 60 + $0 })) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0) min").tag($0) }
            }
        } label: {
            Text(JobText.offsetText(minutes.wrappedValue))
                .meridianFont(.monoBody)
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, Spacing.s)
                .frame(minHeight: Spacing.minTapTarget)
                .background(.bgBase, in: .rect(cornerRadius: Radius.chip, style: .continuous))
        }
        .accessibilityLabel("Offset \(JobText.offsetText(minutes.wrappedValue))")
    }

    // MARK: Save

    private func save() {
        let job = edited
        let isValid = !job.title.isEmpty
            && (try? ScheduleEngine.nextRuns(job.schedule, in: job.zone, after: appState.now(), count: 1)) != nil
        guard isValid else {
            invalidSaves += 1
            showsProblems = true
            return
        }
        var cleaned = job
        cleaned.children = job.children.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        onSave(cleaned)
        dismiss()
    }
}
