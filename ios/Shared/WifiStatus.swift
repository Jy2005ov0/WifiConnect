import Foundation

/// A quick look at whether the Wi-Fi needs signing in. It uses no credentials,
/// so the widget can check it on its own.
enum WifiStatus: String {
    case online
    case loginNeeded
    case offline

    static func check() async -> WifiStatus {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        config.allowsCellularAccess = false // Only the Wi-Fi counts.
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: config)
        let url = URL(string: "http://captive.apple.com/hotspot-detect.html")!
        do {
            let (data, response) = try await session.data(from: url)
            let body = String(decoding: data, as: UTF8.self)
            if response.url?.host == url.host,
               body.range(of: "<body>success</body>", options: .caseInsensitive) != nil {
                return .online
            }
            return .loginNeeded
        } catch {
            return .offline
        }
    }
}
