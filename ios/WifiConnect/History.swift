import Foundation
import UIKit

/// What the app learned about the login page during one sign-in. Never holds the password.
final class LoginTrace {
    var portalURL: URL?
    var formAction: URL?
    var method: String?
    var fieldNames: [String] = []
}

struct HistoryEntry: Codable, Identifiable {
    enum Result: String, Codable {
        case signedIn, alreadyOnline, failed, signedOut, signOutFailed
    }

    var id = UUID()
    var date: Date
    var trigger: SignInTrigger
    var result: Result
    var message: String?
    var portal: String?
    var formAction: String?
    var method: String?
    var fields: [String]?
    var duration: Double
}

/// The last 50 sign-ins, newest first.
enum History {
    private static let key = "signInHistory"
    private static let limit = 50

    static func load() -> [HistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([HistoryEntry].self, from: data)) ?? []
    }

    private static let lock = NSLock()

    /// Sign-ins can finish at the same time (Shortcuts, background, the app): add one at a time.
    static func add(_ entry: HistoryEntry) {
        lock.withLock { save(Array(([entry] + load()).prefix(limit))) }
    }

    static func save(_ entries: [HistoryEntry]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(entries), forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// A login page address without its query string, which can hold session tokens.
    static func describe(_ url: URL?) -> String? {
        guard let url, var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        parts.query = nil
        parts.fragment = nil
        return parts.string
    }
}

/// A plain-text report to send when something goes wrong. Leaves out the password.
enum Diagnostics {
    static func report() -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "?") (\(info["CFBundleVersion"] ?? "?"))"
        let settings = PortalSettings.load()
        let defaults = UserDefaults.standard
        let id = Credentials.studentID
        let maskedID = id.count > 4 ? "\(id.prefix(2))•••\(id.suffix(2))" : (id.isEmpty ? "not set" : "set")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var lines = [
            "WiFi Connect diagnostics",
            "App: \(version)",
            "Device: \(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)",
            "",
            "Wi-Fi name: \(defaults.string(forKey: SettingsKey.wifiName) ?? SettingsKey.defaultWifiName)",
            "Student ID: \(maskedID), password: \(Credentials.password.isEmpty ? "not set" : "set")",
            "Login page: \(settings.useCustomPortal ? "manual" : "automatic")",
        ]
        if settings.useCustomPortal {
            lines += [
                "  URL: \(settings.loginURL)",
                "  Method: \(settings.method)",
                "  Fields: \(settings.usernameField), \(settings.passwordField)",
                "  Extra fields: \(settings.parsedExtraFields.map(\.name).joined(separator: ", "))",
            ]
        }
        lines += ["", "Recent sign-ins:"]
        let entries = History.load().prefix(20)
        if entries.isEmpty { lines.append("  (none yet)") }
        for entry in entries {
            lines.append("- \(formatter.string(from: entry.date))  \(entry.result.rawValue)  via \(entry.trigger.rawValue)  \(String(format: "%.1fs", entry.duration))")
            if let message = entry.message { lines.append("    \(message)") }
            if let portal = entry.portal { lines.append("    page: \(portal)") }
            if let action = entry.formAction {
                lines.append("    form: \(entry.method ?? "?") \(action)")
            }
            if let fields = entry.fields, !fields.isEmpty {
                lines.append("    fields: \(fields.joined(separator: ", "))")
            }
        }
        return lines.joined(separator: "\n")
    }
}
