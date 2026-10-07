import LocalAuthentication

/// Optional Face ID / Touch ID (or passcode) lock in front of Settings, where the password lives.
enum AppLock {
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.requireUnlock)
    }

    /// "Face ID", "Touch ID", "Optic ID" or "Passcode", for labels.
    static var methodName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none: return String(localized: "Passcode")
        @unknown default: return String(localized: "Passcode")
        }
    }

    /// Asks for Face ID / Touch ID, falling back to the passcode. Succeeds straight away
    /// on a phone with no passcode, since there's nothing to unlock with.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return true }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}
