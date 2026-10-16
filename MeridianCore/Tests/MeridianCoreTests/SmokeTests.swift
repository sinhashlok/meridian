import Testing
@testable import MeridianCore

/// Proves the test runner works. Real tests come from docs/design/fixtures.md in M1.
@Test func packageBuildsAndTestsRun() {
    #expect(CoreInfo.version == "0.1.0")
}
