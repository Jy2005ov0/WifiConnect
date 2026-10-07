import Foundation

/// A quick connection check over the Wi-Fi: best of three round trips, then a 10 MB download.
enum SpeedTest {
    struct Result {
        var pingMilliseconds: Int
        var megabitsPerSecond: Double

        var summary: String {
            let speed = megabitsPerSecond >= 10
                ? String(format: "%.0f", megabitsPerSecond)
                : String(format: "%.1f", megabitsPerSecond)
            return String(localized: "\(pingMilliseconds) ms · \(speed) Mbps")
        }
    }

    static func run() async throws -> Result {
        let config = URLSessionConfiguration.ephemeral
        config.allowsCellularAccess = false // Measure the Wi-Fi, not mobile data.
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        // The first request also sets up the connection, so keep the fastest of three.
        let pingURL = URL(string: "https://speed.cloudflare.com/__down?bytes=0")!
        var best = Double.infinity
        for _ in 0..<3 {
            let start = Date()
            _ = try await session.data(from: pingURL)
            best = min(best, Date().timeIntervalSince(start))
        }

        let downloadURL = URL(string: "https://speed.cloudflare.com/__down?bytes=10000000")!
        let start = Date()
        let (data, _) = try await session.data(from: downloadURL)
        let seconds = max(Date().timeIntervalSince(start), 0.001)
        return Result(
            pingMilliseconds: Int((best * 1000).rounded()),
            megabitsPerSecond: Double(data.count) * 8 / seconds / 1_000_000
        )
    }
}
