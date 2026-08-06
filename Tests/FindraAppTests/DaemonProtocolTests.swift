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
}
