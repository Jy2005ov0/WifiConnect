import Foundation

enum SettingsKey {
    static let wifiName = "wifiName"
    static let useCustomPortal = "useCustomPortal"
    static let loginURL = "loginURL"
    static let method = "method"
    static let usernameField = "usernameField"
    static let passwordField = "passwordField"
    static let extraFields = "extraFields"

    /// UTAR's campus Wi-Fi.
    static let defaultWifiName = "utarwifi"
}

/// How to reach the school's login page. By default the page is detected automatically.
struct PortalSettings {
    var useCustomPortal = false
    var loginURL = ""
    var method = "POST"
    var usernameField = "username"
    var passwordField = "password"
    /// Extra `name=value` pairs, one per line.
    var extraFields = ""

    static func load(from defaults: UserDefaults = .standard) -> PortalSettings {
        var s = PortalSettings()
        s.useCustomPortal = defaults.bool(forKey: SettingsKey.useCustomPortal)
        s.loginURL = defaults.string(forKey: SettingsKey.loginURL) ?? s.loginURL
        s.method = defaults.string(forKey: SettingsKey.method) ?? s.method
        s.usernameField = defaults.string(forKey: SettingsKey.usernameField) ?? s.usernameField
        s.passwordField = defaults.string(forKey: SettingsKey.passwordField) ?? s.passwordField
        s.extraFields = defaults.string(forKey: SettingsKey.extraFields) ?? s.extraFields
        return s
    }

    var parsedExtraFields: [FormField] {
        extraFields
            .split(whereSeparator: { $0 == "\n" || $0 == "&" })
            .compactMap { line in
                let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                let name = parts[0].trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return nil }
                let value = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
                return FormField(name: name, value: value)
            }
    }
}
