import Foundation

/// Sangfor access controllers (UTAR's utarwifi): login pages under `/ac_portal/`. The page is drawn
/// by JavaScript and signs in with a background request instead of a form, with the password
/// scrambled with RC4 using the current time as the key.
enum SangforPortal {
    static func isSangfor(_ url: URL) -> Bool {
        url.path.lowercased().hasPrefix("/ac_portal/")
    }

    /// Where the page sends the sign-in (and sign-out) request: `/ac_portal/login.php` on the same host.
    static func loginURL(for portal: URL) -> URL? {
        var parts = URLComponents()
        parts.scheme = portal.scheme ?? "http"
        parts.host = portal.host
        parts.port = portal.port
        parts.path = "/ac_portal/login.php"
        return parts.url
    }

    /// The sign-in request's fields. Newer controllers expect the password scrambled, older ones plain.
    static func signInFields(studentID: String, password: String, scrambled: Bool,
                             now: Date = Date()) -> [FormField] {
        let tag = String(Int64(now.timeIntervalSince1970 * 1000))
        return [
            FormField(name: "opr", value: "pwdLogin"),
            FormField(name: "userName", value: studentID),
            FormField(name: "pwd", value: scrambled ? rc4Hex(password, key: tag) : password),
            FormField(name: "auth_tag", value: tag),
            FormField(name: "rememberPwd", value: "0"),
        ]
    }

    static let signOutFields = [FormField(name: "opr", value: "logout")]

    /// Reads the controller's answer, e.g. `{"success":true,"msg":"logon success"}`. Older ones don't
    /// quote the names, so this doesn't insist on strict JSON.
    static func answer(_ body: String) -> (success: Bool, message: String?) {
        let success = body.range(of: #"["']?success["']?\s*:\s*["']?true"#, options: [.regularExpression, .caseInsensitive]) != nil
        var message: String?
        if let match = body.range(of: #"["']?msg["']?\s*:\s*["']([^"']*)["']"#, options: .regularExpression) {
            let text = String(body[match])
            if let quote = text.dropLast().lastIndex(where: { $0 == "\"" || $0 == "'" }) {
                message = String(text[text.index(after: quote)..<text.index(before: text.endIndex)])
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return (success, message?.isEmpty == true ? nil : message)
    }

    /// RC4 of `text` with `key`, as lowercase hex, the same as the login page's JavaScript.
    static func rc4Hex(_ text: String, key: String) -> String {
        let k = Array(key.utf8)
        guard !k.isEmpty else { return "" }
        var s = (0...255).map { UInt8($0) }
        var j = 0
        for i in 0..<256 {
            j = (j + Int(s[i]) + Int(k[i % k.count])) & 255
            s.swapAt(i, j)
        }
        var i = 0
        j = 0
        var out = ""
        for byte in text.utf8 {
            i = (i + 1) & 255
            j = (j + Int(s[i])) & 255
            s.swapAt(i, j)
            out += String(format: "%02x", byte ^ s[(Int(s[i]) + Int(s[j])) & 255])
        }
        return out
    }
}
