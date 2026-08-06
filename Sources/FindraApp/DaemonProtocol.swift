import Foundation

let appVersion = "1.1.1"
let appProtocolVersion = "1.1.1"

enum EntryKind: String, Codable, CaseIterable {
    case file = "File"
    case directory = "Directory"
    case symlink = "Symlink"
}

enum SortField: String, Codable, CaseIterable {
    case name = "Name"
    case modTime = "ModTime"
    case cTime = "CTime"
    case size = "Size"
    case path = "Path"
}

struct SearchQuery: Codable, Hashable {
    var pattern: String
    var regex = false
    var caseSensitive = false
    var pinyin = false
    var kinds: [EntryKind] = []
    var extensions: [String] = []
    var minSize: UInt64?
    var maxSize: UInt64?
    var pathFilter: String?
    var sortBy: SortField = .name
    var descending = false
    var limit: Int? = 10_000
    var cursor: Int?
    var pageSize: Int?

    enum CodingKeys: String, CodingKey {
        case pattern
        case regex
        case caseSensitive = "case_sensitive"
        case pinyin
        case kinds
        case extensions
        case minSize = "min_size"
        case maxSize = "max_size"
        case pathFilter = "path_filter"
        case sortBy = "sort_by"
        case descending
        case limit
        case cursor
        case pageSize = "page_size"
    }
}

struct SearchPage: Codable, Hashable {
    let entries: [FileEntry]
    let totalMatches: UInt64
    let nextCursor: Int?

    enum CodingKeys: String, CodingKey {
        case entries
        case totalMatches = "total_matches"
        case nextCursor = "next_cursor"
    }
}

struct FileEntry: Identifiable, Codable, Hashable {
    let id: UInt64
    let parentId: UInt64
    let name: String
    let path: String?
    let size: UInt64
    let modifiedAt: Int64
    let createdAt: Int64
    let kind: EntryKind
    let volumeId: UInt32

    enum CodingKeys: String, CodingKey {
        case id
        case parentId = "parent_id"
        case name
        case path
        case size
        case modifiedAt = "mtime"
        case createdAt = "ctime"
        case kind
        case volumeId = "volume_id"
    }
}

struct WatchStatus: Codable, Hashable {
    let path: String
    let live: Bool

    init(path: String, live: Bool) {
        self.path = path
        self.live = live
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.path = try container.decode(String.self)
        self.live = try container.decode(Bool.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(path)
        try container.encode(live)
    }
}

struct IndexStats: Codable, Hashable {
    let totalFiles: UInt64
    let totalSize: UInt64
    let lastSync: Int64
    let providers: [String]
    let watchStatus: [WatchStatus]
    let protocolVersion: String
    let daemonVersion: String
    let databasePath: String
    let databaseSize: UInt64

    enum CodingKeys: String, CodingKey {
        case totalFiles = "total_files"
        case totalSize = "total_size"
        case lastSync = "last_sync"
        case providers
        case watchStatus = "watch_status"
        case protocolVersion = "protocol_version"
        case daemonVersion = "daemon_version"
        case databasePath = "database_path"
        case databaseSize = "database_size"
    }

    init(
        totalFiles: UInt64,
        totalSize: UInt64,
        lastSync: Int64,
        providers: [String],
        watchStatus: [WatchStatus],
        protocolVersion: String,
        daemonVersion: String = "",
        databasePath: String = "",
        databaseSize: UInt64 = 0
    ) {
        self.totalFiles = totalFiles
        self.totalSize = totalSize
        self.lastSync = lastSync
        self.providers = providers
        self.watchStatus = watchStatus
        self.protocolVersion = protocolVersion
        self.daemonVersion = daemonVersion
        self.databasePath = databasePath
        self.databaseSize = databaseSize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.totalFiles = try container.decode(UInt64.self, forKey: .totalFiles)
        self.totalSize = try container.decode(UInt64.self, forKey: .totalSize)
        self.lastSync = try container.decode(Int64.self, forKey: .lastSync)
        self.providers = try container.decode([String].self, forKey: .providers)
        self.watchStatus = try container.decodeIfPresent([WatchStatus].self, forKey: .watchStatus) ?? []
        self.protocolVersion = try container.decodeIfPresent(String.self, forKey: .protocolVersion) ?? ""
        self.daemonVersion = try container.decodeIfPresent(String.self, forKey: .daemonVersion) ?? ""
        self.databasePath = try container.decodeIfPresent(String.self, forKey: .databasePath) ?? ""
        self.databaseSize = try container.decodeIfPresent(UInt64.self, forKey: .databaseSize) ?? 0
    }
}

struct ConfigSnapshot: Codable, Hashable {
    let indexPaths: [String]
    let excludedPaths: [String]
    let autoExcludes: [String]

    enum CodingKeys: String, CodingKey {
        case indexPaths = "index_paths"
        case excludedPaths = "excluded_paths"
        case autoExcludes = "auto_excludes"
    }
}

enum DaemonRequest: Encodable {
    case status
    case search(SearchQuery)
    case searchPage(SearchQuery)
    case index(String)
    case addIndexPath(String)
    case removeIndexPath(String)
    case getConfig
    case addExcludedPath(String)
    case removeExcludedPath(String)
    case subscribeStatus
    case stopDaemon

    func encode(to encoder: Encoder) throws {
        switch self {
        case .status:
            var single = encoder.singleValueContainer()
            try single.encode("Status")
        case .search(let query):
            var keyed = encoder.container(keyedBy: CodingKeys.self)
            try keyed.encode(query, forKey: .search)
        case .searchPage(let query):
            var keyed = encoder.container(keyedBy: CodingKeys.self)
            try keyed.encode(query, forKey: .searchPage)
        case .index(let path):
            var keyed = encoder.container(keyedBy: CodingKeys.self)
            try keyed.encode(path, forKey: .index)
        case .addIndexPath(let path):
            var keyed = encoder.container(keyedBy: CodingKeys.self)
            try keyed.encode(path, forKey: .addIndexPath)
        case .removeIndexPath(let path):
            var keyed = encoder.container(keyedBy: CodingKeys.self)
            try keyed.encode(path, forKey: .removeIndexPath)
        case .getConfig:
            var single = encoder.singleValueContainer()
            try single.encode("GetConfig")
        case .addExcludedPath(let path):
            var keyed = encoder.container(keyedBy: CodingKeys.self)
            try keyed.encode(path, forKey: .addExcludedPath)
        case .removeExcludedPath(let path):
            var keyed = encoder.container(keyedBy: CodingKeys.self)
            try keyed.encode(path, forKey: .removeExcludedPath)
        case .subscribeStatus:
            var single = encoder.singleValueContainer()
            try single.encode("SubscribeStatus")
        case .stopDaemon:
            var single = encoder.singleValueContainer()
            try single.encode("StopDaemon")
        }
    }

    private enum CodingKeys: String, CodingKey {
        case search = "Search"
        case searchPage = "SearchPage"
        case index = "Index"
        case addIndexPath = "AddIndexPath"
        case removeIndexPath = "RemoveIndexPath"
        case addExcludedPath = "AddExcludedPath"
        case removeExcludedPath = "RemoveExcludedPath"
    }
}

enum DaemonResponse: Decodable {
    case status(IndexStats)
    case searchResults([FileEntry])
    case searchPage(SearchPage)
    case config(ConfigSnapshot)
    case indexStarted
    case daemonStopping
    case error(String)

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            switch value {
            case "IndexStarted":
                self = .indexStarted
            case "DaemonStopping":
                self = .daemonStopping
            default:
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown daemon response: \(value)"))
            }
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stats = try container.decodeIfPresent(IndexStats.self, forKey: .status) {
            self = .status(stats)
        } else if let entries = try container.decodeIfPresent([FileEntry].self, forKey: .searchResults) {
            self = .searchResults(entries)
        } else if let page = try container.decodeIfPresent(SearchPage.self, forKey: .searchPage) {
            self = .searchPage(page)
        } else if let config = try container.decodeIfPresent(ConfigSnapshot.self, forKey: .config) {
            self = .config(config)
        } else if let message = try container.decodeIfPresent(String.self, forKey: .error) {
            self = .error(message)
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown daemon response payload"))
        }
    }

    private enum CodingKeys: String, CodingKey {
        case status = "Status"
        case searchResults = "SearchResults"
        case searchPage = "SearchPage"
        case config = "Config"
        case error = "Error"
    }
}
