import XCTest
@testable import FindraApp

@MainActor
final class PreferencesTests: XCTestCase {
    func testExcludedPathsMatchPathAndDescendantsOnly() {
        let suiteName = "FindraAppTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PreferencesViewModel(defaults: defaults)

        preferences.addExcludedPath("/Users/test/Library/Application Scripts")

        XCTAssertTrue(preferences.isPathExcluded("/Users/test/Library/Application Scripts"))
        XCTAssertTrue(preferences.isPathExcluded("/Users/test/Library/Application Scripts/com.example/file.txt"))
        XCTAssertFalse(preferences.isPathExcluded("/Users/test/Library/Application Scripts Backup/file.txt"))
        XCTAssertFalse(preferences.isPathExcluded("/Users/test/Documents/file.txt"))
    }
}
