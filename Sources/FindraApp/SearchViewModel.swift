import AppKit
import Combine
import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var entries: [FileEntry] = []
    @Published var stats: IndexStats?
    @Published var selectedEntry: FileEntry?
    @Published var errorMessage: String?
    @Published var isSearching = false
    @Published var isIndexing = false
    @Published var selectedIndexPath: String?
    @Published var selectedExcludedPath: String?
    @Published var selectedFileType: FileTypeFilter = .all {
        didSet { searchDebounced() }
    }
    @Published var sortBy: FileListSortField = .name {
        didSet { sortVisibleResultsAndRefresh() }
    }
    @Published var descending = false {
        didSet { sortVisibleResultsAndRefresh() }
    }
    @Published var regex = false {
        didSet { searchDebounced() }
    }
    @Published var caseSensitive = false {
        didSet { searchDebounced() }
    }
    @Published var pinyin = false {
        didSet { searchDebounced() }
    }
    @Published var exactName = false {
        didSet { searchDebounced() }
    }
    @Published var pathFilter = "" {
        didSet { searchDebounced() }
    }
    @Published var extensionFilter = "" {
        didSet { searchDebounced() }
    }
    @Published var resultLimit = 1_000 {
        didSet { searchDebounced() }
    }
    @Published var ownersByID: [UInt64: String] = [:]

    private let daemon: DaemonClient
    private let preferences: PreferencesViewModel
    private var searchTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?
    private var lastIndexedFileCount: UInt64 = 0
    private var lastAutomaticListRefresh = Date.distantPast
    private var searchGeneration: UInt64 = 0
    private var ownerTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    init(daemon: DaemonClient, preferences: PreferencesViewModel) {
        self.daemon = daemon
        self.preferences = preferences
        preferences.$excludedPaths
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.objectWillChange.send()
                    self?.searchDebounced(delay: .milliseconds(80))
                }
            }
            .store(in: &cancellables)
    }

    var shouldShowPermissionOnboarding: Bool {
        !preferences.skipPermissionOnboarding && !permissionWarningPaths.isEmpty
    }

    var permissionWarningPaths: [WatchStatus] {
        stats?.watchStatus.filter { !$0.live && !preferences.isPermissionWarningIgnored($0.path) } ?? []
    }

    var excludedPaths: [String] {
        preferences.excludedPaths
    }

    var resultSummary: String {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).count == 1 {
            return "Type at least 2 characters to search"
        }
        let prefix = entries.count >= resultLimit ? "Showing first" : "Showing"
        return "\(prefix) \(entries.count.formatted())"
    }

    var searchPlaceholder: String {
        selectedFileType == .all
            ? "Search files, folders, and paths"
            : "Search \(selectedFileType.title.lowercased())"
    }

    var compatibilityMessage: String? {
        guard let version = stats?.protocolVersion, !version.isEmpty, version != appProtocolVersion else {
            return nil
        }
        return "Compatibility issue: daemon \(version), app \(appProtocolVersion)"
    }

    var versionSummary: String {
        let daemonVersion = stats?.daemonVersion.nilIfEmpty ?? "1.0.0"
        return "Findra \(appVersion) · daemon \(daemonVersion)"
    }

    var indexStoreSummary: String {
        guard let stats else { return "Index store unavailable" }
        return "\(stats.totalFiles.formatted()) indexed · \(Self.byteString(stats.databaseSize)) index db"
    }

    var indexStoreHelp: String {
        guard let path = stats?.databasePath, !path.isEmpty else {
            return "The local index database path is not available yet."
        }
        return "Reveal \(path)"
    }

    var daemonStatus: DaemonDisplayStatus {
        if errorMessage != nil || compatibilityMessage != nil {
            return .problem
        }
        if stats == nil {
            return .starting
        }
        if !permissionWarningPaths.isEmpty {
            return .limited
        }
        return .running
    }

    var emptyResultsMessage: String {
        if isSearching {
            return "Loading indexed files..."
        }
        if query.trimmingCharacters(in: .whitespacesAndNewlines).count == 1 {
            return "Type at least 2 characters to search."
        }
        if let total = stats?.totalFiles, total > 0 {
            return query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Preparing the file list while indexing continues..."
                : "No indexed files match this search."
        }
        return "Indexing files..."
    }

    func startStatusSubscription() {
        guard statusTask == nil else { return }
        statusTask = Task {
            while !Task.isCancelled {
                do {
                    for try await stats in daemon.statusUpdates() {
                        applyStatus(stats)
                    }
                } catch {
                    guard !Task.isCancelled else { break }
                    errorMessage = error.localizedDescription
                    do {
                        applyStatus(try await daemon.status())
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func refreshStatus() {
        Task {
            do {
                applyStatus(try await daemon.status())
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func applyStatus(_ stats: IndexStats) {
        let totalChanged = stats.totalFiles != lastIndexedFileCount
        self.stats = stats
        lastIndexedFileCount = stats.totalFiles
        if selectedIndexPath == nil {
            selectedIndexPath = stats.watchStatus.first?.path
        }
        errorMessage = nil
        refreshVisibleIndexIfNeeded(totalChanged: totalChanged, totalFiles: stats.totalFiles)
    }

    private func refreshVisibleIndexIfNeeded(totalChanged: Bool, totalFiles: UInt64) {
        guard totalChanged, totalFiles > 0 else { return }
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard entries.isEmpty || Date().timeIntervalSince(lastAutomaticListRefresh) >= 2 else { return }
        lastAutomaticListRefresh = Date()
        searchDebounced(delay: .milliseconds(150))
    }

    func searchDebounced() {
        searchDebounced(delay: .milliseconds(300))
    }

    private func searchDebounced(delay: Duration) {
        searchTask?.cancel()
        searchGeneration += 1
        let generation = searchGeneration
        searchTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await runSearch(generation: generation)
        }
    }

    func runSearch() async {
        searchTask?.cancel()
        searchGeneration += 1
        await runSearch(generation: searchGeneration)
    }

    private func runSearch(generation: UInt64) async {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).count == 1 {
            guard generation == searchGeneration else { return }
            entries = []
            selectedEntry = nil
            errorMessage = nil
            return
        }

        isSearching = true
        defer {
            if generation == searchGeneration {
                isSearching = false
            }
        }

        do {
            let request = makeSearchQuery()
            let results = try await daemon.search(request)
            guard generation == searchGeneration, !Task.isCancelled else { return }
            entries = locallyFiltered(results)
            sortVisibleResults()
            loadOwners(for: entries)
            selectedEntry = entries.first
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            guard generation == searchGeneration else { return }
            entries = []
            selectedEntry = nil
            errorMessage = error.localizedDescription
        }
    }

    private func sortVisibleResultsAndRefresh() {
        sortVisibleResults()
        searchDebounced(delay: .milliseconds(250))
    }

    private func sortVisibleResults() {
        guard !entries.isEmpty else { return }
        let selectedID = selectedEntry?.id
        entries.sort { lhs, rhs in
            let result = compare(lhs, rhs)
            return descending ? result == .orderedDescending : result == .orderedAscending
        }
        if let selectedID {
            selectedEntry = entries.first { $0.id == selectedID } ?? entries.first
        } else {
            selectedEntry = entries.first
        }
    }

    private func compare(_ lhs: FileEntry, _ rhs: FileEntry) -> ComparisonResult {
        let result: ComparisonResult
        switch sortBy {
        case .name:
            result = lhs.name.localizedStandardCompare(rhs.name)
        case .modTime:
            result = compare(lhs.modifiedAt, rhs.modifiedAt)
        case .cTime:
            result = compare(lhs.createdAt, rhs.createdAt)
        case .size:
            result = compare(lhs.size, rhs.size)
        case .path:
            result = (lhs.path ?? "").localizedStandardCompare(rhs.path ?? "")
        case .owner:
            result = owner(for: lhs).localizedStandardCompare(owner(for: rhs))
        }
        if result != .orderedSame {
            return result
        }
        let pathResult = (lhs.path ?? "").localizedStandardCompare(rhs.path ?? "")
        if pathResult != .orderedSame {
            return pathResult
        }
        return compare(lhs.id, rhs.id)
    }

    private func compare<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }

    func rebuildFirstWatchedPath() {
        guard let path = stats?.watchStatus.first?.path else { return }
        rebuildIndex(path: path)
    }

    func rebuildSelectedIndexPath() {
        guard let path = selectedIndexPath ?? stats?.watchStatus.first?.path else { return }
        rebuildIndex(path: path)
    }

    func promptForIndexPath() {
        guard let path = promptForPath(
            title: "Add Indexed Path",
            message: "Type or paste a folder path to index.",
            placeholder: "/Users/name/Documents",
            confirmTitle: "Add"
        ) else { return }
        addIndexPath(path)
    }

    func chooseIndexPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"

        guard panel.runModal() == .OK, let path = panel.url?.path else { return }
        addIndexPath(path)
    }

    private func addIndexPath(_ path: String) {
        let normalized = Self.normalizedInputPath(path)
        guard !normalized.isEmpty else { return }
        Task {
            do {
                isIndexing = true
                defer { isIndexing = false }
                try await daemon.addIndexPath(normalized)
                selectedIndexPath = normalized
                refreshStatus()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func removeSelectedIndexPath() {
        guard let path = selectedIndexPath ?? stats?.watchStatus.first?.path else { return }
        Task {
            do {
                isIndexing = true
                defer { isIndexing = false }
                try await daemon.removeIndexPath(path)
                selectedIndexPath = nil
                refreshStatus()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func promptForExcludedPath() {
        guard let path = promptForPath(
            title: "Add Excluded Path",
            message: "Type or paste a file or folder path to hide from results.",
            placeholder: "/Users/name/Library/Caches",
            confirmTitle: "Exclude"
        ) else { return }
        addExcludedPath(path)
    }

    func chooseExcludedPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Exclude"

        guard panel.runModal() == .OK, let path = panel.url?.path else { return }
        addExcludedPath(path)
    }

    private func addExcludedPath(_ path: String) {
        let normalized = Self.normalizedInputPath(path)
        guard !normalized.isEmpty else { return }
        preferences.addExcludedPath(normalized)
        selectedExcludedPath = preferences.normalizedExcludedPath(normalized)
    }

    func removeSelectedExcludedPath() {
        guard let path = selectedExcludedPath ?? preferences.excludedPaths.first else { return }
        preferences.removeExcludedPath(path)
        selectedExcludedPath = nil
    }

    private func rebuildIndex(path: String) {
        Task {
            do {
                isIndexing = true
                defer { isIndexing = false }
                try await daemon.rebuildIndex(path: path)
                refreshStatus()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func openSelected() {
        guard let url = selectedEntry?.fileURL else { return }
        NSWorkspace.shared.open(url)
    }

    func revealSelected() {
        guard let url = selectedEntry?.fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func revealIndexDatabase() {
        guard let path = stats?.databasePath, !path.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func copySelectedPath() {
        guard let path = selectedEntry?.fileURL?.path else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }

    func skipPermissionOnboarding() {
        preferences.skipPermissionOnboarding = true
    }

    func ignoreCurrentPermissionWarnings() {
        for item in permissionWarningPaths {
            preferences.ignorePermissionWarning(path: item.path)
        }
    }

    private func makeSearchQuery() -> SearchQuery {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = exactName && !trimmedQuery.isEmpty
            ? "^\(NSRegularExpression.escapedPattern(for: trimmedQuery))$"
            : trimmedQuery
        let manualExtensions = extensionFilter
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "."))) }
            .filter { !$0.isEmpty }
        let extensions = manualExtensions.isEmpty
            ? selectedFileType.extensions
            : manualExtensions

        return SearchQuery(
            pattern: pattern,
            regex: regex || exactName,
            caseSensitive: caseSensitive,
            pinyin: pinyin && !exactName,
            extensions: extensions,
            pathFilter: pathFilter.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            sortBy: sortBy.daemonSortField,
            descending: descending,
            limit: resultLimit
        )
    }

    private func locallyFiltered(_ entries: [FileEntry]) -> [FileEntry] {
        entries.filter { entry in
            if preferences.isPathExcluded(entry.path) {
                return false
            }
            if selectedFileType == .folders {
                return entry.kind == .directory
            }
            return true
        }
    }

    func owner(for entry: FileEntry) -> String {
        ownersByID[entry.id] ?? "-"
    }

    private func loadOwners(for entries: [FileEntry]) {
        ownerTask?.cancel()
        let targets = entries.filter { ownersByID[$0.id] == nil }
        guard !targets.isEmpty else { return }
        ownerTask = Task.detached(priority: .utility) { [weak self] in
            let pairs: [(UInt64, String)] = targets.map { entry in
                guard let path = entry.path else { return (entry.id, "-") }
                let owner = (try? FileManager.default.attributesOfItem(atPath: path)[.ownerAccountName] as? String) ?? "-"
                return (entry.id, owner)
            }
            await MainActor.run {
                guard let self, !Task.isCancelled else { return }
                for (id, owner) in pairs {
                    self.ownersByID[id] = owner
                }
                if self.sortBy == .owner {
                    self.sortVisibleResults()
                }
            }
        }
    }

    private static func byteString(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func promptForPath(title: String, message: String, placeholder: String, confirmTitle: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 420, height: 24))
        field.placeholderString = placeholder
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let path = Self.normalizedInputPath(field.stringValue)
        return path.isEmpty ? nil : path
    }

    private static func normalizedInputPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let expanded = (trimmed as NSString).expandingTildeInPath
        let standardized = URL(fileURLWithPath: expanded).standardizedFileURL.path
        if standardized == "/" {
            return standardized
        }
        return standardized.hasSuffix("/") ? String(standardized.dropLast()) : standardized
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

extension SortField {
    var displayName: String {
        switch self {
        case .name:
            return "Name"
        case .modTime:
            return "Modified"
        case .cTime:
            return "Created"
        case .size:
            return "Size"
        case .path:
            return "Path"
        }
    }
}

enum FileListSortField: String, CaseIterable {
    case name
    case path
    case size
    case modTime
    case cTime
    case owner

    var displayName: String {
        switch self {
        case .name: "Name"
        case .path: "Path"
        case .size: "Size"
        case .modTime: "Modified"
        case .cTime: "Created"
        case .owner: "Owner"
        }
    }

    var daemonSortField: SortField {
        switch self {
        case .name, .owner: .name
        case .path: .path
        case .size: .size
        case .modTime: .modTime
        case .cTime: .cTime
        }
    }
}

enum FileTypeFilter: String, CaseIterable {
    case all
    case folders
    case documents
    case images
    case audio
    case videos
    case archives
    case code
    case apps

    var title: String {
        switch self {
        case .all: "All"
        case .folders: "Folders"
        case .documents: "Documents"
        case .images: "Images"
        case .audio: "Audio"
        case .videos: "Videos"
        case .archives: "Archives"
        case .code: "Code"
        case .apps: "Applications"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "tray.full"
        case .folders: "folder"
        case .documents: "doc.text"
        case .images: "photo"
        case .audio: "music.note"
        case .videos: "film"
        case .archives: "archivebox"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .apps: "app"
        }
    }

    var extensions: [String] {
        switch self {
        case .all, .folders:
            []
        case .documents:
            ["doc", "docx", "md", "numbers", "pages", "pdf", "ppt", "pptx", "rtf", "txt", "xls", "xlsx"]
        case .images:
            ["gif", "heic", "jpeg", "jpg", "png", "raw", "svg", "tif", "tiff", "webp"]
        case .audio:
            ["aac", "aiff", "flac", "m4a", "mp3", "wav"]
        case .videos:
            ["avi", "m4v", "mkv", "mov", "mp4", "webm"]
        case .archives:
            ["7z", "bz2", "dmg", "gz", "rar", "tar", "tgz", "xz", "zip"]
        case .code:
            ["c", "cc", "cpp", "css", "go", "h", "html", "java", "js", "json", "kt", "m", "mm", "py", "rs", "sh", "swift", "toml", "ts", "tsx", "xml", "yaml", "yml"]
        case .apps:
            ["app"]
        }
    }
}

enum DaemonDisplayStatus {
    case running
    case limited
    case starting
    case problem

    var label: String {
        switch self {
        case .running: "Running"
        case .limited: "Limited"
        case .starting: "Starting"
        case .problem: "Issue"
        }
    }

    var color: NSColor {
        switch self {
        case .running: .systemGreen
        case .limited: .systemOrange
        case .starting: .systemGray
        case .problem: .systemRed
        }
    }
}

private extension FileEntry {
    var fileURL: URL? {
        if let path, !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}
