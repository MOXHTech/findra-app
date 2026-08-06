import Foundation

actor DaemonSupervisor {
    static let shared = DaemonSupervisor()

    private var spawnedProcess: Process?

    func ensureRunning(socketPath: String, forceRestart: Bool = false) async throws {
        if !forceRestart, FileManager.default.fileExists(atPath: socketPath) {
            return
        }

        if forceRestart {
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        let binary = try locateDaemon()
        try spawnDaemon(binary)
        try await waitForSocket(socketPath)
    }

    private func locateDaemon() throws -> URL {
        if let override = ProcessInfo.processInfo.environment["FINDRA_DAEMON_BIN"] {
            let url = URL(fileURLWithPath: override)
            if isExecutable(url) {
                return url
            }
        }

        let bundleCandidates = [
            Bundle.main.resourceURL?.appending(path: "vendor-bin/findra-daemon"),
            Bundle.main.resourceURL?.appending(path: "findra-daemon")
        ].compactMap { $0 }

        for candidate in bundleCandidates where isExecutable(candidate) {
            return candidate
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
        let repoRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let siblingFindra = repoRoot
            .deletingLastPathComponent()
            .appending(path: "findra")

        let devCandidates = [
            siblingFindra.appending(path: "target/release/findra-daemon"),
            siblingFindra.appending(path: "target/debug/findra-daemon")
        ]

        for candidate in devCandidates where isExecutable(candidate) {
            return candidate
        }

        if let pathCandidate = findOnPath("findra-daemon") {
            return pathCandidate
        }

        throw DaemonClientError.notRunning("bundled findra-daemon was not found")
    }

    private func spawnDaemon(_ binary: URL) throws {
        if let process = spawnedProcess, process.isRunning {
            return
        }

        let findraDir = URL(fileURLWithPath: NSHomeDirectory()).appending(path: ".findra")
        try FileManager.default.createDirectory(at: findraDir, withIntermediateDirectories: true)
        let logURL = findraDir.appending(path: "daemon.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)

        let logHandle = try FileHandle(forWritingTo: logURL)
        try logHandle.seekToEnd()

        let process = Process()
        process.executableURL = binary
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = logHandle
        process.standardError = logHandle
        try process.run()
        spawnedProcess = process
    }

    private func waitForSocket(_ socketPath: String) async throws {
        for attempt in 0..<50 {
            if FileManager.default.fileExists(atPath: socketPath) {
                return
            }
            if attempt < 49 {
                try await Task.sleep(for: .milliseconds(100))
            }
        }
        throw DaemonClientError.notRunning(socketPath)
    }

    private func isExecutable(_ url: URL) -> Bool {
        FileManager.default.isExecutableFile(atPath: url.path)
    }

    private func findOnPath(_ name: String) -> URL? {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in path.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appending(path: name)
            if isExecutable(candidate) {
                return candidate
            }
        }
        return nil
    }
}
