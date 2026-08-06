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
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? true
        self.globalShortcut = defaults.string(forKey: "globalShortcut") ?? "Option Space"
        self.skipPermissionOnboarding = defaults.object(forKey: "skipPermissionOnboarding") as? Bool ?? false
        self.ignoredPermissionPaths = defaults.stringArray(forKey: "ignoredPermissionPaths") ?? []
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
