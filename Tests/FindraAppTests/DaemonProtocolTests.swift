import Foundation
import XCTest
@testable import FindraApp

final class DaemonProtocolTests: XCTestCase {
    func testStatusRequestMatchesDaemonWireShape() throws {
        let data = try JSONEncoder().encode(DaemonRequest.status)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"Status\"")
    }

    func testIndexPathMutationRequestsMatchDaemonWireShape() throws {
        let add = try JSONEncoder().encode(DaemonRequest.addIndexPath("/tmp/docs"))
        let remove = try JSONEncoder().encode(DaemonRequest.removeIndexPath("/tmp/docs"))

        XCTAssertEqual(String(data: add, encoding: .utf8), "{\"AddIndexPath\":\"\\/tmp\\/docs\"}")
        XCTAssertEqual(String(data: remove, encoding: .utf8), "{\"RemoveIndexPath\":\"\\/tmp\\/docs\"}")
    }

    func testConfigRequestsMatchDaemonWireShape() throws {
        let get = try JSONEncoder().encode(DaemonRequest.getConfig)
        let add = try JSONEncoder().encode(DaemonRequest.addExcludedPath("/tmp/cache"))
        let remove = try JSONEncoder().encode(DaemonRequest.removeExcludedPath("/tmp/cache"))

        XCTAssertEqual(String(data: get, encoding: .utf8), "\"GetConfig\"")
        XCTAssertEqual(String(data: add, encoding: .utf8), "{\"AddExcludedPath\":\"\\/tmp\\/cache\"}")
        XCTAssertEqual(String(data: remove, encoding: .utf8), "{\"RemoveExcludedPath\":\"\\/tmp\\/cache\"}")
    }

    func testSubscribeStatusRequestMatchesDaemonWireShape() throws {
        let data = try JSONEncoder().encode(DaemonRequest.subscribeStatus)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"SubscribeStatus\"")
    }

    func testSearchResponseDecodesExternalTaggedResults() throws {
        let json = """
        {
          "SearchResults": [
            {
              "id": 1,
              "parent_id": 0,
              "name": "README.md",
              "path": "/tmp/README.md",
              "size": 12,
              "mtime": 10,
              "ctime": 8,
              "kind": "File",
              "volume_id": 2
            }
          ]
        }
        """

        let response = try JSONDecoder().decode(DaemonResponse.self, from: Data(json.utf8))
        guard case .searchResults(let entries) = response else {
            return XCTFail("expected search results")
        }

        XCTAssertEqual(entries.first?.name, "README.md")
        XCTAssertEqual(entries.first?.path, "/tmp/README.md")
    }

    func testSearchPageResponseDecodesExternalTaggedPage() throws {
        let json = """
        {
          "SearchPage": {
            "entries": [
              {
                "id": 1,
                "parent_id": 0,
                "name": "README.md",
                "path": "/tmp/README.md",
                "size": 12,
                "mtime": 10,
                "ctime": 8,
                "kind": "File",
                "volume_id": 2
              }
            ],
            "total_matches": 2,
            "next_cursor": 1
          }
        }
        """

        let response = try JSONDecoder().decode(DaemonResponse.self, from: Data(json.utf8))
        guard case .searchPage(let page) = response else {
            return XCTFail("expected search page")
        }

        XCTAssertEqual(page.entries.first?.name, "README.md")
        XCTAssertEqual(page.totalMatches, 2)
        XCTAssertEqual(page.nextCursor, 1)
    }

    func testConfigResponseDecodesExternalTaggedSnapshot() throws {
        let json = """
        {
          "Config": {
            "index_paths": ["/Users/test"],
            "excluded_paths": ["/Users/test/Library"],
            "auto_excludes": ["/System"]
          }
        }
        """

        let response = try JSONDecoder().decode(DaemonResponse.self, from: Data(json.utf8))
        guard case .config(let config) = response else {
            return XCTFail("expected config")
        }

        XCTAssertEqual(config.indexPaths, ["/Users/test"])
        XCTAssertEqual(config.excludedPaths, ["/Users/test/Library"])
        XCTAssertEqual(config.autoExcludes, ["/System"])
    }
}
