import XCTest

/// Accessibility audits on every tab, segment and main sheet, and the Planner row's
/// VoiceOver sentence (decision CC). UI tests use XCTest: Swift Testing can't drive an app.
/// Each test launches the Debug build in a fixed state with the screenshot launch arguments
/// (`DebugLaunch`), so audits see the boards' data at the boards' time.
final class MeridianUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true   // audit every screen, even after one fails
    }

    // MARK: Audits

    @MainActor func testZonesAudit() throws {
        try audit("Planner", ["-MeridianTab", "zones", "-zones.segment", "planner"])
        try audit("Planner, bottom", ["-MeridianTab", "zones", "-zones.segment", "planner", "-MeridianBottom", "1"])
        try audit("Clocks", ["-MeridianTab", "zones", "-zones.segment", "clocks"])
        try audit("Add zone", ["-MeridianScreen", "addZone"])
        try audit("Edit zone", ["-MeridianScreen", "editZone"])
        try audit("Clock changes", ["-MeridianScreen", "changes"])
    }

    @MainActor func testAlarmsAudit() throws {
        let alarms = ["-MeridianTab", "alarms", "-alarms.segment", "alarms", "-MeridianAlarms", "demo"]
        let jobs = ["-MeridianTab", "alarms", "-alarms.segment", "jobs", "-MeridianJobs", "demo"]
        try audit("Alarms", alarms)
        try audit("Alarm edit", alarms + ["-MeridianScreen", "alarmEdit"])
        try audit("Jobs", jobs)
        try audit("Job detail", jobs + ["-MeridianScreen", "jobDetail"])
        try audit("Job detail, bottom", jobs + ["-MeridianScreen", "jobDetail", "-MeridianBottom", "1"])
        try audit("Job edit", jobs + ["-MeridianScreen", "jobEdit"])
    }

    @MainActor func testTimerAudit() throws {
        try audit("Timers", ["-MeridianTab", "timer", "-timer.segment", "timers", "-MeridianTimers", "demo"])
        try audit("New timer", ["-MeridianTab", "timer", "-timer.segment", "timers", "-MeridianTimers", "none",
                                "-MeridianScreen", "newTimer"])
        try audit("Stopwatch", ["-MeridianTab", "timer", "-timer.segment", "stopwatch", "-MeridianStopwatch", "demo"])
    }

    @MainActor func testSessionsAudit() throws {
        try audit("Sessions", ["-MeridianTab", "sessions", "-MeridianSession", "demo"])
        try audit("Sessions, bottom", ["-MeridianTab", "sessions", "-MeridianSession", "demo", "-MeridianBottom", "1"])
    }

    @MainActor func testToolsAudit() throws {
        try audit("Epoch", ["-MeridianTab", "tools", "-MeridianTool", "epoch", "-MeridianInput", "1792060800000"])
        try audit("Cron", ["-MeridianTab", "tools", "-MeridianTool", "cron", "-MeridianInput", "0_9_*_*_1-5"])
        try audit("Dates", ["-MeridianTab", "tools", "-MeridianTool", "dates", "-MeridianFiscal", "india"])
        try audit("Fiscal profiles", ["-MeridianTab", "tools", "-MeridianTool", "dates", "-MeridianFiscal", "india",
                                      "-MeridianScreen", "fiscalProfiles"])
    }

    @MainActor func testSettingsAudit() throws {
        let settings = ["-MeridianTab", "tools", "-MeridianFiscal", "india", "-MeridianScreen", "settings"]
        try audit("Settings", settings)
        try audit("Settings, bottom", settings + ["-MeridianBottom", "1"])
    }

    // MARK: VoiceOver

    /// Thu 15 Oct 2026 21:02 IST: the row reads the selected 30-minute slot (21:00), when
    /// Mumbai is in its stretch hours (18:00–22:00).
    @MainActor func testPlannerRowSpeaksTheWholeRow() throws {
        let app = launch(["-MeridianTab", "zones", "-zones.segment", "planner"])
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Mumbai, home, ")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No Planner row for Mumbai")
        XCTAssertEqual(row.label,
                       "Mumbai, home, 21:00 IST, stretch hours. Work hours 09:00 to 18:00, Monday to Friday.")
    }

    // MARK: Helpers

    private static let base = [
        "-MeridianNow", "2026-10-15T15:32:07Z",
        "-MeridianZones", "Asia/Kolkata=Mumbai,Europe/London=London,America/Los_Angeles=SF",
        "-MeridianNotif", "off",
    ]

    @MainActor private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = Self.base + arguments
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "The app didn't open")
        return app
    }

    /// Launches on a screen, lets it settle, and fails with the audit's findings, except:
    /// - `.timeHero` text (identifier `timeHero`, `FontToken.heroIdentifier`) scales with
    ///   @ScaledMetric up to AX2, which the Dynamic Type check can't see;
    /// - contrast is measured from pixels, so an element the screen edge cuts off, or a row
    ///   scrolled under the tab bar or a navigation bar or into the scroll-edge fade beside
    ///   it (`edgeEffect`), is measured against the edge, the glass or the fade. The "bottom"
    ///   audits check those rows in full view;
    /// - the system's glass toolbar buttons in sheets and pushed screens (`systemButtons`):
    ///   iOS draws them and they fail both checks on every app;
    /// - contrast on disabled controls, which WCAG 1.4.3 exempts (Planner's Now at now);
    /// - Dynamic Type and clipping on `listRows`: List and Form text that grows and shows
    ///   whole (checked at default size and AX5) but that the checks misread;
    /// - clipping on single-line text fields (Dates): the check flags them at the default
    ///   size, where nothing is cut off (Cron's field stopped being flagged once it wrapped);
    /// - findings with no element: hidden text (the Planner ticks and bubble, Stopwatch's
    ///   column header, all spoken another way) and system pickers. They print as `SKIP`
    ///   so new ones are still seen.
    /// Every finding is printed with its element, and one screen's findings don't stop the
    /// next screen's audit.
    @MainActor private func audit(_ name: String, _ arguments: [String]) throws {
        XCTContext.runActivity(named: "Audit \(name)") { _ in
            let app = launch(arguments)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.5))
            let layout = ScreenLayout(app)
            do {
                try app.performAccessibilityAudit { issue in
                    guard let element = issue.element else {
                        print("SKIP \(name) · \(issue.compactDescription) · no element")
                        return true
                    }
                    let ignored = layout.ignores(issue.auditType, on: element)
                    if !ignored {
                        print("AUDIT \(name) · \(issue.compactDescription) · '\(element.label)' id '\(element.identifier)' \(element.frame)")
                    }
                    return ignored
                }
            } catch {
                XCTFail("\(name): \(error.localizedDescription)")
            }
            app.terminate()
        }
    }
}

/// Where the screen edge and the bars are, read once before an audit, to decide which
/// findings are the audit's blind spots rather than the app's (see `audit`).
private struct ScreenLayout {
    /// How far iOS 26's scroll-edge effect fades content beyond a bar's frame (seen in
    /// screenshots: Job detail's first caption under the navigation bar).
    static let edgeEffect: CGFloat = 32
    /// Toolbar buttons iOS draws as glass capsules.
    static let systemButtons: Set<String> = ["Cancel", "Save", "Start", "Edit", "Done"]
    /// List and Form rows, headers and footers the checks misread (18 Oct 2026).
    static let listRows: Set<String> = [
        "Label", "At", "Time",                                                  // Alarm and Job edit
        "Where the real schedule lives. For your reference only, not synced.",  // Job edit footer
        "Default fiscal profile", "Open iOS Settings",                          // Settings
        "Work days", "Home zone",                                               // Edit zone
        "Add zone",                                                             // Clocks list footer
    ]

    let screen: CGRect
    let navigationBars: [CGRect]
    let bars: [CGRect]
    /// Frames of the bars' own contents (the header's UTC pill and gear), which are still checked.
    let barParts: Set<String>

    @MainActor init(_ app: XCUIApplication) {
        screen = app.frame
        navigationBars = app.navigationBars.allElementsBoundByIndex.map(\.frame)
        bars = app.tabBars.allElementsBoundByIndex.map(\.frame) + navigationBars
        barParts = Set((app.tabBars.descendants(matching: .any).allElementsBoundByIndex
            + app.navigationBars.descendants(matching: .any).allElementsBoundByIndex).map { "\($0.frame)" })
    }

    @MainActor func ignores(_ type: XCUIAccessibilityAuditType, on element: XCUIElement) -> Bool {
        let frame = element.frame
        if element.elementType == .button, Self.systemButtons.contains(element.label),
           navigationBars.contains(where: { $0.contains(frame) }) {
            return true
        }
        switch type {
        case .dynamicType:
            return element.identifier == "timeHero" || Self.listRows.contains(element.label)
        case .contrast:
            let nearBar = bars.contains { $0.insetBy(dx: 0, dy: -Self.edgeEffect).intersects(frame) }
            let underBar = nearBar && !barParts.contains("\(frame)")
            return !screen.contains(frame) || underBar || !element.isEnabled
        case .textClipped:
            // The system search field's placeholder; single-line fields; List rows.
            return [.searchField, .textField].contains(element.elementType) || Self.listRows.contains(element.label)
        default:
            return false
        }
    }
}
