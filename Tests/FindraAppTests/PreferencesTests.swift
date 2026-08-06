import XCTest
@testable import FindraApp

@MainActor
final class PreferencesTests: XCTestCase {
    func testPermissionWarningIgnoreListPersists() {
        let suiteName = "FindraAppTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PreferencesViewModel(defaults: defaults)

        preferences.ignorePermissionWarning(path: "/Users/test/Library/Application Scripts")

        XCTAssertTrue(preferences.isPermissionWarningIgnored("/Users/test/Library/Application Scripts"))
        XCTAssertFalse(preferences.isPermissionWarningIgnored("/Users/test/Documents"))
    }
}
