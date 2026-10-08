import Foundation
import Observation

/// A full connection test over the Wi-Fi, like a speed test app: ping and jitter,
/// then download and upload, each over several parallel connections for a few seconds.
@MainActor
@Observable
final class SpeedTest {
    enum Phase: Equatable {
        case idle, ping, download, upload, done
        case failed(String)
    }

    var phase: Phase = .idle
    /// The speed right now, for the gauge (Mbps).
    var liveMbps: Double = 0
    /// How far through the current stage (0…1).
    var progress: Double = 0
    var ping: Double?
    var jitter: Double?
    var download: Double?
    var upload: Double?

    var isRunning: Bool {
        switch phase {
        case .ping, .download, .upload: return true
        default: return false
        }
    }

    /// A short line for the main screen, e.g. "↓ 92 · ↑ 41 Mbps".
    var summary: String? {
        guard phase == .done, let download, let upload else { return nil }
        return "↓ \(Self.format(download)) · ↑ \(Self.format(upload)) Mbps"
    }

    static func format(_ mbps: Double) -> String {
        mbps >= 10 ? String(format: "%.0f", mbps) : String(format: "%.1f", mbps)
    }

    nonisolated private static let server = "https://speed.cloudflare.com"
    private static let stageSeconds = 8.0
    private static let streams = 4
    @ObservationIgnored private var task: Task<Void, Never>?

    func start() {
        task?.cancel()
        ping = nil; jitter = nil; download = nil; upload = nil
        liveMbps = 0; progress = 0
        task = Task { await run() }
    }

    func stop() {
        task?.cancel()
        task = nil
        if isRunning { phase = .idle }
        liveMbps = 0
    }

    private func run() async {
        do {
            phase = .ping
            try await measurePing()
            phase = .download
            download = try await measureTransfer(upload: false)
            phase = .upload
            upload = try await measureTransfer(upload: true)
            liveMbps = 0
            phase = .done
        } catch {
            // Stopping cancels the requests too, which isn't a failure.
            if Task.isCancelled || (error as? URLError)?.code == .cancelled { return }
            liveMbps = 0
            phase = .failed(String(localized: "Couldn't reach the test server. Make sure you're connected to the Wi-Fi and online."))
        }
    }

    private static func session(delegate: URLSessionDelegate? = nil) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.allowsCellularAccess = false // Measure the Wi-Fi, not mobile data.
        config.timeoutIntervalForRequest = 10
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpMaximumConnectionsPerHost = streams
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    /// Ten small requests on one connection: the median is the ping, the average change is the jitter.
    private func measurePing() async throws {
        let session = Self.session()
        defer { session.invalidateAndCancel() }
        let url = URL(string: "\(Self.server)/__down?bytes=0")!
        _ = try await session.data(from: url) // Sets up the connection.
        var samples: [Double] = []
        for i in 0..<10 {
            try Task.checkCancellation()
            let start = Date()
            _ = try await session.data(from: url)
            samples.append(Date().timeIntervalSince(start) * 1000)
            progress = Double(i + 1) / 10
            ping = samples.sorted()[samples.count / 2]
        }
        let changes = zip(samples, samples.dropFirst()).map { abs($0 - $1) }
        jitter = changes.isEmpty ? 0 : changes.reduce(0, +) / Double(changes.count)
    }

    /// Runs parallel transfers for a few seconds, updating the gauge, and returns the average Mbps.
    private func measureTransfer(upload: Bool) async throws -> Double {
        let counter = TransferCounter()
        let session = Self.session(delegate: counter)
        defer {
            counter.stop()
            session.invalidateAndCancel()
        }
        counter.onTaskFinished = { [weak counter] error in
            // Keep the pipes full until the stage ends.
            if error == nil, counter?.isStopped == false { Self.startStream(session, upload: upload) }
        }
        for _ in 0..<Self.streams { Self.startStream(session, upload: upload) }

        let start = Date()
        var last = (time: start, bytes: Int64(0))
        // The first second ramps up, so the average counts from then.
        var warm: (time: Date, bytes: Int64)?
        while true {
            try await Task.sleep(nanoseconds: 250_000_000)
            let now = Date()
            let bytes = counter.total
            let elapsed = now.timeIntervalSince(start)
            let instant = Double(bytes - last.bytes) * 8 / now.timeIntervalSince(last.time) / 1_000_000
            liveMbps = liveMbps == 0 ? instant : liveMbps * 0.6 + instant * 0.4
            last = (now, bytes)
            progress = min(elapsed / Self.stageSeconds, 1)
            if warm == nil, elapsed >= 1 { warm = (now, bytes) }
            if counter.failed, bytes == 0 { throw URLError(.cannotConnectToHost) }
            if elapsed >= Self.stageSeconds { break }
        }
        guard let warm, last.time > warm.time else { return liveMbps }
        return Double(last.bytes - warm.bytes) * 8 / last.time.timeIntervalSince(warm.time) / 1_000_000
    }

    nonisolated private static func startStream(_ session: URLSession, upload: Bool) {
        if upload {
            var request = URLRequest(url: URL(string: "\(server)/__up")!)
            request.httpMethod = "POST"
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            session.uploadTask(with: request, from: Data(count: 25_000_000)).resume()
        } else {
            session.dataTask(with: URL(string: "\(server)/__down?bytes=100000000")!).resume()
        }
    }

    #if DEBUG
    /// A finished result for the README screenshots.
    func showDemoResult() {
        ping = 18; jitter = 3; download = 92.4; upload = 41.7
        progress = 1
        phase = .done
    }
    #endif
}

/// Counts bytes received and sent by every task in a session.
private final class TransferCounter: NSObject, URLSessionDataDelegate {
    private let lock = NSLock()
    private var bytes: Int64 = 0
    private var anyFailed = false
    private var stopped = false
    var onTaskFinished: ((Error?) -> Void)?

    var total: Int64 { lock.withLock { bytes } }
    var failed: Bool { lock.withLock { anyFailed } }
    var isStopped: Bool { lock.withLock { stopped } }

    func stop() {
        lock.withLock { stopped = true }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.withLock { bytes += Int64(data.count) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        lock.withLock { bytes += bytesSent }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error, (error as? URLError)?.code != .cancelled {
            lock.withLock { anyFailed = true }
        }
        onTaskFinished?(error)
    }
}
