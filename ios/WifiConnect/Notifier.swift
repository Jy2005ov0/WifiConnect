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

    /// `delay` lets the README screenshots catch the banner on the Home Screen.
    static func signedIn(delay: TimeInterval = 0) async {
        guard isEnabled else { return }
        let network = UserDefaults.standard.string(forKey: SettingsKey.wifiName) ?? SettingsKey.defaultWifiName
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Connected to \(network)")
        content.body = String(localized: "You're signed in and online.")
        content.threadIdentifier = "sign-in"
        // Reusing the identifier replaces the previous notification instead of stacking them.
        let trigger = delay > 0 ? UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false) : nil
        let request = UNNotificationRequest(identifier: "sign-in", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
