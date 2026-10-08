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
        // Unsigned simulator builds (used for screenshots and tests) can't use the Keychain.
        let defaults = UserDefaults.standard
        if let testID = defaults.string(forKey: "testStudentID") {
            return account == "studentID" ? testID : (defaults.string(forKey: "testPassword") ?? "")
        }
        if let demoID = defaults.string(forKey: "demoStudentID") {
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
        guard !value.isEmpty else {
            SecItemDelete(query(account) as CFDictionary)
            return
        }
        // Update in place rather than delete and re-add: with a save on every keystroke, a re-add
        // that failed left the previous value behind (the last digit of the ID went missing).
        let data = Data(value.utf8)
        var status = SecItemUpdate(query(account) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var q = query(account)
            q[kSecValueData as String] = data
            // Readable after the first unlock so the Shortcuts automation works with the phone in your pocket.
            q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(q as CFDictionary, nil)
        }
        if status != errSecSuccess {
            print("WifiConnect: couldn't save \(account) to the Keychain (\(status))")
        }
    }
}
