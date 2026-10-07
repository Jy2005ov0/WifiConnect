import Foundation
import Security

/// Student ID and password, kept in the iOS Keychain.
enum Credentials {
    private static let service = Bundle.main.bundleIdentifier ?? "WifiConnect"

    static var studentID: String {
        get { read("studentID") }
        set { write(newValue, for: "studentID") }
    }

    static var password: String {
        get { read("password") }
        set { write(newValue, for: "password") }
    }

    static var isConfigured: Bool { !studentID.isEmpty && !password.isEmpty }

    private static func query(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func read(_ account: String) -> String {
        #if DEBUG
        // Unsigned simulator builds (used for screenshots) can't use the Keychain.
        if let demoID = UserDefaults.standard.string(forKey: "demoStudentID") {
            return account == "studentID" ? demoID : "password"
        }
        #endif
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    private static func write(_ value: String, for account: String) {
        SecItemDelete(query(account) as CFDictionary)
        guard !value.isEmpty else { return }
        var q = query(account)
        q[kSecValueData as String] = Data(value.utf8)
        // Readable after the first unlock so the Shortcuts automation works with the phone in your pocket.
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
}
