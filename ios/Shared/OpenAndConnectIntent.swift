import AppIntents
import Foundation

/// Set when a widget or Control Center tap asks to sign in, in case the app wasn't
/// running yet to hear the notification below.
@MainActor
enum ConnectRequest {
    static var pending = false
}

extension Notification.Name {
    /// Posted when a widget or Control Center button asks the app to sign in.
    static let connectRequested = Notification.Name("WifiConnect.connectRequested")
}

/// Opens WiFi Connect and signs in. Used by the Control Center button and the widget.
struct OpenAndConnectIntent: AppIntent {
    static var title: LocalizedStringResource = "Sign In to Campus Wi-Fi"
    static var description = IntentDescription("Opens WiFi Connect and signs in to the campus Wi-Fi.")
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        ConnectRequest.pending = true
        NotificationCenter.default.post(name: .connectRequested, object: nil)
        return .result()
    }
}
