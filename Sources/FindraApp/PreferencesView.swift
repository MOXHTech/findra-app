import SwiftUI

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    @Published var globalShortcut: String {
        didSet { defaults.set(globalShortcut, forKey: "globalShortcut") }
    }
    @Published var skipPermissionOnboarding: Bool {
        didSet { defaults.set(skipPermissionOnboarding, forKey: "skipPermissionOnboarding") }
    }
    @Published private(set) var ignoredPermissionPaths: [String] {
        didSet { defaults.set(ignoredPermissionPaths, forKey: "ignoredPermissionPaths") }
    }
    @Published private(set) var excludedPaths: [String] {
        didSet { defaults.set(excludedPaths, forKey: "excludedPaths") }
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? true
        self.globalShortcut = defaults.string(forKey: "globalShortcut") ?? "Option Space"
        self.skipPermissionOnboarding = defaults.object(forKey: "skipPermissionOnboarding") as? Bool ?? false
        self.ignoredPermissionPaths = defaults.stringArray(forKey: "ignoredPermissionPaths") ?? []
        self.excludedPaths = Self.normalizedUnique(defaults.stringArray(forKey: "excludedPaths") ?? [])
    }

    func isPermissionWarningIgnored(_ path: String) -> Bool {
        ignoredPermissionPaths.contains(path)
    }

    func ignorePermissionWarning(path: String) {
        guard !ignoredPermissionPaths.contains(path) else { return }
        ignoredPermissionPaths.append(path)
    }

    func removeIgnoredPermissionPath(_ path: String) {
        ignoredPermissionPaths.removeAll { $0 == path }
    }

    func addExcludedPath(_ path: String) {
        let normalized = normalizedExcludedPath(path)
        guard !normalized.isEmpty, !excludedPaths.contains(normalized) else { return }
        excludedPaths.append(normalized)
        excludedPaths.sort { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func removeExcludedPath(_ path: String) {
        let normalized = normalizedExcludedPath(path)
        excludedPaths.removeAll { $0 == normalized }
    }

    func isPathExcluded(_ path: String?) -> Bool {
        guard let candidate = path.map(normalizedExcludedPath), !candidate.isEmpty else { return false }
        return excludedPaths.contains { excluded in
            candidate == excluded || candidate.hasPrefix(excluded + "/")
        }
    }

    func normalizedExcludedPath(_ path: String) -> String {
        Self.normalizedPath(path)
    }

    private static func normalizedUnique(_ paths: [String]) -> [String] {
        Array(Set(paths.map(normalizedPath).filter { !$0.isEmpty }))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private static func normalizedPath(_ path: String) -> String {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        if standardized == "/" {
            return standardized
        }
        return standardized.hasSuffix("/") ? String(standardized.dropLast()) : standardized
    }
}

struct PreferencesView: View {
    @ObservedObject var model: PreferencesViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch Findra at login", isOn: $model.launchAtLogin)
                LabeledContent("Global shortcut", value: model.globalShortcut)
                Toggle("Hide permission warning", isOn: $model.skipPermissionOnboarding)
            }

            Section("Permission warning whitelist") {
                if model.ignoredPermissionPaths.isEmpty {
                    Text("No paths are hidden from permission warnings.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.ignoredPermissionPaths, id: \.self) { path in
                        HStack {
                            Text(path)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                model.removeIgnoredPermissionPath(path)
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section("Excluded paths") {
                if model.excludedPaths.isEmpty {
                    Text("No paths are excluded from search results.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.excludedPaths, id: \.self) { path in
                        HStack {
                            Text(path)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                model.removeExcludedPath(path)
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section("Search engine") {
                LabeledContent("Findra", value: appVersion)
                Text("Findra uses one local index shared by the app and CLI.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding()
        .frame(width: 520)
        .background(FindraPalette.windowBackground(colorScheme))
    }
}
