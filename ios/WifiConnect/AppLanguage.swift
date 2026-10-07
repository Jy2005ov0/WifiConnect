import Foundation

/// The app's own language, separate from the phone's. `.system` follows the phone.
/// iOS reads the choice when the app starts, so it takes effect after reopening the app.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = ""
    case english = "en"
    case malay = "ms"
    case chinese = "zh-Hans"
    case japanese = "ja"
    case tamil = "ta"

    var id: String { rawValue }

    /// Each language's name in itself, so anyone can find their own.
    var nativeName: String {
        switch self {
        case .system: return ""
        case .english: return "English"
        case .malay: return "Bahasa Melayu"
        case .chinese: return "简体中文"
        case .japanese: return "日本語"
        case .tamil: return "தமிழ்"
        }
    }

    private static let appleLanguages = "AppleLanguages"
    private static let storageKey = "appLanguage"

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    func apply() {
        let defaults = UserDefaults.standard
        if self == .system {
            defaults.removeObject(forKey: Self.storageKey)
            defaults.removeObject(forKey: Self.appleLanguages)
        } else {
            defaults.set(rawValue, forKey: Self.storageKey)
            defaults.set([rawValue], forKey: Self.appleLanguages)
        }
    }
}
