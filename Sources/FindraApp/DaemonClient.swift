import Darwin
import Foundation

protocol DaemonClient: Sendable {
    func status() async throws -> IndexStats
    func statusUpdates() -> AsyncThrowingStream<IndexStats, Error>
    func search(_ query: SearchQuery) async throws -> [FileEntry]
    func rebuildIndex(path: String) async throws
    func addIndexPath(_ path: String) async throws
    func removeIndexPath(_ path: String) async throws
}

enum DaemonClientError: LocalizedError {
    case notRunning(String)
    case unexpectedResponse
    case daemon(String)
    case socket(String)
    case frameTooLarge(UInt32)

    var errorDescription: String? {
        switch self {
        case .notRunning(let path):
            return "findra daemon is not running at \(path)"
        case .unexpectedResponse:
            return "findra daemon returned an unexpected response"
        case .daemon(let message):
            return message
        case .socket(let message):
            return message
        case .frameTooLarge(let size):
            return "findra daemon frame is too large: \(size) bytes"
        }
    }
}

struct SocketDaemonClient: DaemonClient {
    private let socketPath: String
    private let supervisor: DaemonSupervisor
    private let maxFrameBytes: UInt32 = 256 * 1024 * 1024

    init(
        socketPath: String = "\(NSHomeDirectory())/.findra/daemon.sock",
        supervisor: DaemonSupervisor = .shared
    ) {
        self.socketPath = socketPath
        self.supervisor = supervisor
    }

    func status() async throws -> IndexStats {
        switch try await send(.status) {
        case .status(let stats):
            return stats
        case .error(let message):
            throw DaemonClientError.daemon(message)
        default:
            throw DaemonClientError.unexpectedResponse
        }
    }

    func statusUpdates() -> AsyncThrowingStream<IndexStats, Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .utility) {
                do {
                    try await supervisor.ensureRunning(socketPath: socketPath)
                    let fd = try openSocket(socketPath)
                    defer { close(fd) }

                    let body = try JSONEncoder().encode(DaemonRequest.subscribeStatus)
                    var frame = UInt32(body.count).bigEndianBytes
                    frame.append(body)
                    try writeAll(frame, to: fd)

                    while !Task.isCancelled {
                        let response = try readResponse(from: fd, maxFrameBytes: maxFrameBytes)
                        switch response {
                        case .status(let stats):
                            continuation.yield(stats)
                        case .error(let message):
                            throw DaemonClientError.daemon(message)
                        default:
                            throw DaemonClientError.unexpectedResponse
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func search(_ query: SearchQuery) async throws -> [FileEntry] {
        switch try await send(.search(query)) {
        case .searchResults(let entries):
            return entries
        case .error(let message):
            throw DaemonClientError.daemon(message)
        default:
            throw DaemonClientError.unexpectedResponse
        }
    }

    func rebuildIndex(path: String) async throws {
        switch try await send(.index(path)) {
        case .indexStarted:
            return
        case .error(let message):
            throw DaemonClientError.daemon(message)
        default:
            throw DaemonClientError.unexpectedResponse
        }
    }

    func addIndexPath(_ path: String) async throws {
        switch try await send(.addIndexPath(path)) {
        case .indexStarted:
            return
        case .error(let message):
            throw DaemonClientError.daemon(message)
        default:
            throw DaemonClientError.unexpectedResponse
        }
    }

    func removeIndexPath(_ path: String) async throws {
        switch try await send(.removeIndexPath(path)) {
        case .indexStarted:
            return
        case .error(let message):
            throw DaemonClientError.daemon(message)
        default:
            throw DaemonClientError.unexpectedResponse
        }
    }

    private func send(_ request: DaemonRequest) async throws -> DaemonResponse {
        do {
            return try await sendFrame(request)
        } catch DaemonClientError.notRunning {
            try await supervisor.ensureRunning(socketPath: socketPath)
            return try await sendFrame(request)
        } catch DaemonClientError.socket(let message) where message == "Connection refused" || message == "No such file or directory" {
            try await supervisor.ensureRunning(socketPath: socketPath, forceRestart: true)
            return try await sendFrame(request)
        }
    }

    private func sendFrame(_ request: DaemonRequest) async throws -> DaemonResponse {
        try await Task.detached(priority: .userInitiated) {
            let body = try JSONEncoder().encode(request)
            var frame = UInt32(body.count).bigEndianBytes
            frame.append(body)

            let fd = try openSocket(socketPath)
            defer { close(fd) }

            try writeAll(frame, to: fd)
            return try readResponse(from: fd, maxFrameBytes: maxFrameBytes)
        }.value
    }
}

private func openSocket(_ socketPath: String) throws -> Int32 {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
        throw DaemonClientError.socket(String(cString: strerror(errno)))
    }

    guard FileManager.default.fileExists(atPath: socketPath) else {
        close(fd)
        throw DaemonClientError.notRunning(socketPath)
    }

    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    try socketPath.withCString { pathPointer in
        let pathCapacity = MemoryLayout.size(ofValue: address.sun_path)
        if strlen(pathPointer) >= pathCapacity {
            close(fd)
            throw DaemonClientError.socket("socket path is too long")
        }
        _ = withUnsafeMutablePointer(to: &address.sun_path) { tuplePointer in
            tuplePointer.withMemoryRebound(to: CChar.self, capacity: pathCapacity) { charPointer in
                strncpy(charPointer, pathPointer, pathCapacity - 1)
            }
        }
    }

    let connectResult = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketPointer in
            connect(fd, socketPointer, socklen_t(MemoryLayout<sa_family_t>.size + socketPath.utf8.count + 1))
        }
    }
    guard connectResult == 0 else {
        let message = String(cString: strerror(errno))
        close(fd)
        throw DaemonClientError.socket(message)
    }
    return fd
}

private func readResponse(from fd: Int32, maxFrameBytes: UInt32) throws -> DaemonResponse {
    let header = try readExact(4, from: fd)
    let size = UInt32(bigEndianBytes: header)
    guard size <= maxFrameBytes else {
        throw DaemonClientError.frameTooLarge(size)
    }

    let responseBody = try readExact(Int(size), from: fd)
    return try JSONDecoder().decode(DaemonResponse.self, from: responseBody)
}

private func writeAll(_ data: Data, to fd: Int32) throws {
    try data.withUnsafeBytes { buffer in
        guard let base = buffer.baseAddress else { return }
        var sent = 0
        while sent < data.count {
            let count = Darwin.write(fd, base.advanced(by: sent), data.count - sent)
            guard count > 0 else {
                throw DaemonClientError.socket(String(cString: strerror(errno)))
            }
            sent += count
        }
    }
}

private func readExact(_ count: Int, from fd: Int32) throws -> Data {
    var data = Data(count: count)
    try data.withUnsafeMutableBytes { buffer in
        guard let base = buffer.baseAddress else { return }
        var received = 0
        while received < count {
            let readCount = Darwin.read(fd, base.advanced(by: received), count - received)
            guard readCount > 0 else {
                throw DaemonClientError.socket(readCount == 0 ? "socket closed" : String(cString: strerror(errno)))
            }
            received += readCount
        }
    }
    return data
}

private extension UInt32 {
    var bigEndianBytes: Data {
        var value = self.bigEndian
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }

    init(bigEndianBytes data: Data) {
        self = data.withUnsafeBytes { buffer in
            UInt32(bigEndian: buffer.load(as: UInt32.self))
        }
    }
}
