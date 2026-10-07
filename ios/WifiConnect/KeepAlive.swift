import BackgroundTasks
import Foundation

/// Stay signed in: in the background, check now and then whether the campus Wi-Fi has
/// logged you out, and sign back in. iOS decides exactly when this runs.
enum KeepAlive {
    static let identifier = "com.wificonnect.keepalive"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.staySignedIn) as? Bool ?? true
    }

    static func schedule() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        guard isEnabled, Credentials.isConfigured else { return }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func run() async {
        schedule()
        guard isEnabled, Credentials.isConfigured else { return }
        guard await WifiStatus.check() == .loginNeeded else { return }
        if (try? await SignIn.run(.background)) == .loggedIn {
            await Notifier.signedIn()
        }
    }
}
