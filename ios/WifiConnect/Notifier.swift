import Foundation
import UserNotifications

/// "Connected to utarwifi" notifications when the app signs in on its own.
enum Notifier {
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.notifyOnConnect) as? Bool ?? true
    }

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func signedIn() async {
        guard isEnabled else { return }
        let network = UserDefaults.standard.string(forKey: SettingsKey.wifiName) ?? SettingsKey.defaultWifiName
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Connected to \(network)")
        content.body = String(localized: "You're signed in and online.")
        content.threadIdentifier = "sign-in"
        // Reusing the identifier replaces the previous notification instead of stacking them.
        let request = UNNotificationRequest(identifier: "sign-in", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
