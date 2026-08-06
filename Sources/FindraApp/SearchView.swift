import SwiftUI

struct SearchView: View {
    @ObservedObject var model: SearchViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
        } detail: {
            VStack(spacing: 0) {
                if model.shouldShowPermissionOnboarding {
                    PermissionOnboardingView(
                        paths: model.permissionWarningPaths,
                        onOpenSettings: openFullDiskAccessSettings,
                        onIgnore: model.ignoreCurrentPermissionWarnings,
                    onSkip: model.skipPermissionOnboarding
                )
                Divider()
                    .overlay(FindraPalette.separator(colorScheme))
                }
                toolbar
                Divider()
                    .overlay(FindraPalette.separator(colorScheme))
                ResultsView(
                    model: model,
                    actions: ResultActions(open: model.openSelected, reveal: model.revealSelected, copyPath: model.copySelectedPath)
                )
                Divider()
                    .overlay(FindraPalette.separator(colorScheme))
                StatusBarView(model: model)
            }
            .background(FindraPalette.windowBackground(colorScheme))
        }
        .background(FindraPalette.windowBackground(colorScheme))
        .task {
            model.startStatusSubscription()
            model.refreshStatus()
            await model.runSearch()
        }
    }

    private var toolbar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                TextField(model.searchPlaceholder, text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .onChange(of: model.query) {
                        model.searchDebounced()
                    }
                if model.isSearching || model.isIndexing {
                    ProgressView()
                        .controlSize(.small)
                }
                Button {
                    model.rebuildSelectedIndexPath()
                } label: {
                    Label("Rebuild", systemImage: "arrow.clockwise")
                }
                .disabled(model.selectedIndexPath == nil && model.stats?.watchStatus.first == nil)
                Button {
                    model.revealSelected()
                } label: {
                    Label("Reveal", systemImage: "folder")
                }
                .disabled(model.selectedEntry == nil)
            }

            HStack(spacing: 10) {
                Menu {
                    Toggle("Case sensitive", isOn: $model.caseSensitive)
                    Toggle("Exact name", isOn: $model.exactName)
                    Toggle("Pinyin", isOn: $model.pinyin)
                    Toggle("Regular expression", isOn: $model.regex)
                    Divider()
                    TextField("Path starts with", text: $model.pathFilter)
                    TextField("Extensions, e.g. swift,md", text: $model.extensionFilter)
                } label: {
                    Label("Search", systemImage: "line.3.horizontal.decrease.circle")
                }

                if model.regex || model.caseSensitive || model.exactName || !model.pathFilter.isEmpty || !model.extensionFilter.isEmpty || model.selectedFileType != .all || !model.excludedPaths.isEmpty {
                    Label("Filtered", systemImage: "line.3.horizontal.decrease")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(FindraPalette.toolbar(colorScheme))
    }

    private func openFullDiskAccessSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
    }
}

private struct PermissionOnboardingView: View {
    let paths: [WatchStatus]
    let onOpenSettings: () -> Void
    let onIgnore: () -> Void
    let onSkip: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Some indexed paths need permission")
                    .font(.headline)
                Text(paths.map(\.path).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Open Settings", action: onOpenSettings)
            Button("Don't warn for these", action: onIgnore)
            Button("Dismiss", action: onSkip)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(FindraPalette.toolbar(colorScheme))
    }
}

private struct ResultActions {
    let open: () -> Void
    let reveal: () -> Void
    let copyPath: () -> Void
}

private struct SidebarView: View {
    @ObservedObject var model: SearchViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        List {
            Section("File types") {
                ForEach(FileTypeFilter.allCases, id: \.self) { type in
                    Button {
                        model.selectedFileType = type
                    } label: {
                        Label(type.title, systemImage: type.systemImage)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(model.selectedFileType == type ? FindraPalette.selectedRow(colorScheme) : FindraPalette.sidebar(colorScheme))
                }
            }

            Section {
                if let paths = model.stats?.watchStatus, !paths.isEmpty {
                    ForEach(paths, id: \.path) { item in
                        Button {
                            model.selectedIndexPath = item.path
                        } label: {
                            HStack(spacing: 10) {
                                Text(item.path)
                                    .lineLimit(1)
                                if !item.live {
                                    Image(systemName: "clock.badge.exclamationmark")
                                        .foregroundStyle(.orange)
                                        .help("This path is not currently receiving live filesystem events.")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(model.selectedIndexPath == item.path ? FindraPalette.selectedRow(colorScheme) : FindraPalette.sidebar(colorScheme))
                    }
                } else {
                    Text("No indexed paths reported")
                        .foregroundStyle(.secondary)
                        .listRowBackground(FindraPalette.sidebar(colorScheme))
                }
            } header: {
                HStack {
                    Text("Indexed paths")
                    Spacer()
                    Button {
                        model.promptForIndexPath()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("Type an index path")
                    Button {
                        model.chooseIndexPath()
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .buttonStyle(.borderless)
                    .help("Choose a folder to index")
                    Button {
                        model.removeSelectedIndexPath()
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove selected index path")
                    .disabled(model.selectedIndexPath == nil)
                }
            }

            Section {
                if model.excludedPaths.isEmpty {
                    Text("No excluded paths")
                        .foregroundStyle(.secondary)
                        .listRowBackground(FindraPalette.sidebar(colorScheme))
                } else {
                    ForEach(model.excludedPaths, id: \.self) { path in
                        Button {
                            model.selectedExcludedPath = path
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "nosign")
                                    .foregroundStyle(.secondary)
                                Text(path)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(model.selectedExcludedPath == path ? FindraPalette.selectedRow(colorScheme) : FindraPalette.sidebar(colorScheme))
                    }
                }
            } header: {
                HStack {
                    Text("Excluded paths")
                    Spacer()
                    Button {
                        model.promptForExcludedPath()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("Type an excluded path")
                    Button {
                        model.chooseExcludedPath()
                    } label: {
                        Image(systemName: "folder.badge.minus")
                    }
                    .buttonStyle(.borderless)
                    .help("Choose a file or folder to exclude")
                    Button {
                        model.removeSelectedExcludedPath()
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove selected excluded path")
                    .disabled(model.selectedExcludedPath == nil && model.excludedPaths.isEmpty)
                }
            }
        }
        .navigationTitle("Findra")
        .scrollContentBackground(.hidden)
        .background(FindraPalette.sidebar(colorScheme))
    }
}

private struct ResultsView: View {
    @ObservedObject var model: SearchViewModel
    let actions: ResultActions
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            FileHeaderView(model: model)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.entries) { entry in
                        FileRowView(
                            entry: entry,
                            owner: model.owner(for: entry),
                            isSelected: model.selectedEntry?.id == entry.id,
                            onSelect: { model.selectedEntry = entry },
                            actions: actions
                        )
                        .onAppear {
                            model.loadNextPageIfNeeded(current: entry)
                        }
                    }
                    if model.isLoadingNextPage {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading more")
                                .foregroundStyle(.secondary)
                        }
                        .font(.footnote)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                }
            }
        }
        .background(FindraPalette.surface(colorScheme))
        .overlay {
            if model.entries.isEmpty {
                ContentUnavailableView {
                    Label("No files to show yet", systemImage: "tray")
                } description: {
                    Text(model.emptyResultsMessage)
                }
            }
        }
    }
}

private struct FileHeaderView: View {
    @ObservedObject var model: SearchViewModel

    var body: some View {
        HStack(spacing: FileColumns.spacing) {
            SortHeader("Name", field: .name, model: model)
                .frame(width: FileColumns.name, alignment: .leading)
            SortHeader("Path", field: .path, model: model)
                .frame(minWidth: FileColumns.pathMin, maxWidth: .infinity, alignment: .leading)
            SortHeader("Size", field: .size, model: model)
                .frame(width: FileColumns.size, alignment: .trailing)
            SortHeader("Modified", field: .modTime, model: model)
                .frame(width: FileColumns.date, alignment: .leading)
            SortHeader("Created", field: .cTime, model: model)
                .frame(width: FileColumns.date, alignment: .leading)
            SortHeader("Owner", field: .owner, model: model)
                .frame(width: FileColumns.owner, alignment: .leading)
        }
        .font(.callout.weight(.semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.thinMaterial)
    }
}

private struct SortHeader: View {
    let title: String
    let field: FileListSortField
    @ObservedObject var model: SearchViewModel

    init(_ title: String, field: FileListSortField, model: SearchViewModel) {
        self.title = title
        self.field = field
        self.model = model
    }

    var body: some View {
        Button {
            if model.sortBy == field {
                model.descending.toggle()
            } else {
                model.sortBy = field
                model.descending = false
            }
        } label: {
            HStack(spacing: 4) {
                if field == .size {
                    Spacer(minLength: 0)
                }
                Text(title)
                    .lineLimit(1)
                if model.sortBy == field {
                    Image(systemName: model.descending ? "chevron.down" : "chevron.up")
                        .font(.caption2.weight(.bold))
                }
                if field != .size {
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.sortBy == field ? Color.accentColor : .primary)
    }
}

private struct FileRowView: View {
    let entry: FileEntry
    let owner: String
    let isSelected: Bool
    let onSelect: () -> Void
    let actions: ResultActions
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: FileColumns.spacing) {
            HStack(spacing: 8) {
                Image(systemName: symbol(for: entry.kind))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(entry.name)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(width: FileColumns.name, alignment: .leading)
            Text(entry.path ?? "")
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(minWidth: FileColumns.pathMin, maxWidth: .infinity, alignment: .leading)
            Text(entry.kind == .directory ? "-" : ByteCountFormatter.string(fromByteCount: Int64(entry.size), countStyle: .file))
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: FileColumns.size, alignment: .trailing)
            Text(dateString(entry.modifiedAt))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: FileColumns.date, alignment: .leading)
            Text(dateString(entry.createdAt))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: FileColumns.date, alignment: .leading)
            Text(owner)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: FileColumns.owner, alignment: .leading)
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(isSelected ? FindraPalette.selectedRow(colorScheme) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button("Open", action: actions.open)
            Button("Reveal in Finder", action: actions.reveal)
            Button("Copy Path", action: actions.copyPath)
        }
    }

    private func symbol(for kind: EntryKind) -> String {
        switch kind {
        case .file: "doc"
        case .directory: "folder"
        case .symlink: "arrow.triangle.branch"
        }
    }
}

private enum FileColumns {
    static let spacing: CGFloat = 16
    static let name: CGFloat = 320
    static let pathMin: CGFloat = 360
    static let size: CGFloat = 86
    static let date: CGFloat = 170
    static let owner: CGFloat = 120
}

private struct StatusBarView: View {
    @ObservedObject var model: SearchViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else if let compatibility = model.compatibilityMessage {
                Label(compatibility, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else {
                Label(model.resultSummary, systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
            Text(model.indexStoreSummary)
                .foregroundStyle(.secondary)
                .help(model.indexStoreHelp)
                .onTapGesture(perform: model.revealIndexDatabase)
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(nsColor: model.daemonStatus.color))
                    .frame(width: 8, height: 8)
                Text("\(model.daemonStatus.label) · \(model.versionSummary)")
            }
            .foregroundStyle(.secondary)
        }
        .font(.footnote)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(FindraPalette.statusBar(colorScheme))
    }
}

private func dateString(_ timestamp: Int64) -> String {
    guard timestamp > 0 else { return "-" }
    return Date(timeIntervalSince1970: TimeInterval(timestamp)).formatted(date: .abbreviated, time: .shortened)
}
