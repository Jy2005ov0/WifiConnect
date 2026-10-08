import Foundation

struct FormField {
    var name: String
    var value: String
}

/// A request that submits a login form.
struct FormSubmission {
    var url: URL
    var method: String
    var fields: [FormField]
}

/// A small, forgiving HTML scanner that finds the login form on a captive portal page.
struct HTMLForm {
    struct Input {
        var name: String
        var type: String
        var value: String
        var checked: Bool
    }

    var action: URL
    var method: String
    var inputs: [Input]
    /// The page the form was found on.
    var pageURL: URL

    var passwordField: String? {
        inputs.first { $0.type == "password" }?.name
    }

    var usernameField: String? {
        let textTypes: Set<String> = ["text", "email", "tel", "number", ""]
        let candidates = inputs.filter { textTypes.contains($0.type) }
        let hints = ["user", "login", "account", "student", "matric", "uid", "email", "id", "name"]
        for hint in hints {
            if let match = candidates.first(where: { $0.name.lowercased().contains(hint) }) {
                return match.name
            }
        }
        return candidates.first?.name
    }

    /// Fills in the student ID and password, keeping hidden fields the portal expects.
    func submission(username: String, password: String) -> FormSubmission? {
        guard let passwordName = passwordField else { return nil }
        let usernameName = usernameField
        var fields: [FormField] = []
        var addedSubmit = false

        for input in inputs {
            switch input.type {
            case "password":
                fields.append(FormField(name: input.name, value: input.name == passwordName ? password : input.value))
            case "checkbox":
                // Usually "I agree to the terms" or "remember me": tick it.
                fields.append(FormField(name: input.name, value: input.value.isEmpty ? "on" : input.value))
            case "radio":
                if input.checked { fields.append(FormField(name: input.name, value: input.value)) }
            case "submit":
                if !addedSubmit {
                    fields.append(FormField(name: input.name, value: input.value))
                    addedSubmit = true
                }
            case "image":
                // Browsers send where an image button was clicked, not its value.
                if !addedSubmit {
                    fields.append(FormField(name: input.name + ".x", value: "0"))
                    fields.append(FormField(name: input.name + ".y", value: "0"))
                    addedSubmit = true
                }
            case "button", "reset", "file":
                continue
            default:
                let value = input.name == usernameName ? username : input.value
                fields.append(FormField(name: input.name, value: value))
            }
        }
        return FormSubmission(url: action, method: method, fields: fields)
    }

    // MARK: - Parsing

    /// The first form on the page that has a password box.
    static func loginForm(in html: String, baseURL: URL) -> HTMLForm? {
        let clean = stripComments(html)
        for match in clean.regexMatches(#"<form\b([^>]*)>(.*?)</form\s*>"#) {
            let attrs = attributes(match[1] ?? "")
            let body = match[2] ?? ""
            let inputs = parseControls(body)
            guard inputs.contains(where: { $0.type == "password" }) else { continue }

            let actionString = attrs["action"].map(decodeEntities) ?? ""
            let action = actionString.isEmpty
                ? baseURL
                : (URL(string: actionString, relativeTo: baseURL)?.absoluteURL ?? baseURL)
            let method = (attrs["method"] ?? "get").uppercased() == "POST" ? "POST" : "GET"
            return HTMLForm(action: action, method: method, inputs: inputs, pageURL: baseURL)
        }
        return nil
    }

    /// Follows `<meta http-equiv="refresh">` and simple JavaScript redirects that portals use.
    static func clientRedirect(in html: String, baseURL: URL) -> URL? {
        let clean = stripComments(html)
        var target: String?

        for match in clean.regexMatches(#"<meta\b([^>]*)>"#) {
            let attrs = attributes(match[1] ?? "")
            guard attrs["http-equiv"]?.lowercased() == "refresh", let content = attrs["content"] else { continue }
            if let url = decodeEntities(content).regexMatches(#"url\s*=\s*['"]?([^'"]+)"#).first?[1] {
                target = url
                break
            }
        }

        if target == nil {
            let patterns = [
                #"location\.replace\(\s*['"]([^'"]+)['"]"#,
                #"location(?:\.href)?\s*=\s*['"]([^'"]+)['"]"#,
            ]
            for pattern in patterns {
                if let url = clean.regexMatches(pattern).first?[1] {
                    target = url
                    break
                }
            }
        }

        guard let target = target?.trimmingCharacters(in: .whitespaces), !target.isEmpty else { return nil }
        return URL(string: target, relativeTo: baseURL)?.absoluteURL
    }

    /// A "Log out" link or form on the page shown after signing in, if there is one.
    static func signOutLink(in html: String, baseURL: URL) -> URL? {
        let words = "(?:logout|log-out|log_out|logoff|log-off|signout|sign-out|sign_out)"
        let patterns = [
            #"<a\b[^>]*href\s*=\s*["']([^"']*"# + words + #"[^"']*)["']"#,
            #"<form\b[^>]*action\s*=\s*["']([^"']*"# + words + #"[^"']*)["']"#,
        ]
        let clean = stripComments(html)
        for pattern in patterns {
            for match in clean.regexMatches(pattern) {
                // Skip links that only run JavaScript ("javascript:logout()") or don't resolve.
                guard let link = match[1],
                      let url = URL(string: decodeEntities(link), relativeTo: baseURL)?.absoluteURL,
                      url.scheme == "http" || url.scheme == "https" else { continue }
                return url
            }
        }
        return nil
    }

    /// The form's fields in page order: inputs, drop-downs, text areas and named buttons.
    /// Disabled fields are left out, as browsers do.
    private static func parseControls(_ html: String) -> [Input] {
        let pattern = #"<input\b([^>]*)>|<select\b([^>]*)>(.*?)</select\s*>|<textarea\b([^>]*)>(.*?)</textarea\s*>|<button\b([^>]*)>(.*?)</button\s*>"#
        return html.regexMatches(pattern).compactMap { match in
            if let tag = match[1] {
                let attrs = attributes(tag)
                guard let name = attrs["name"], !name.isEmpty, attrs["disabled"] == nil else { return nil }
                return Input(name: decodeEntities(name), type: (attrs["type"] ?? "text").lowercased(),
                             value: decodeEntities(attrs["value"] ?? ""), checked: attrs["checked"] != nil)
            }
            if let tag = match[2] {
                let attrs = attributes(tag)
                guard let name = attrs["name"], !name.isEmpty, attrs["disabled"] == nil else { return nil }
                // The selected option, or the first one, like a browser.
                let options = (match[3] ?? "").regexMatches(#"<option\b([^>]*)>([^<]*)"#).map { option in
                    (attributes(option[1] ?? ""), option[2] ?? "")
                }
                let chosen = options.first { $0.0["selected"] != nil } ?? options.first
                let value = chosen.map { $0.0["value"] ?? $0.1.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
                return Input(name: decodeEntities(name), type: "select", value: decodeEntities(value), checked: false)
            }
            if let tag = match[4] {
                let attrs = attributes(tag)
                guard let name = attrs["name"], !name.isEmpty, attrs["disabled"] == nil else { return nil }
                return Input(name: decodeEntities(name), type: "textarea", value: decodeEntities(match[5] ?? ""), checked: false)
            }
            if let tag = match[6] {
                let attrs = attributes(tag)
                guard let name = attrs["name"], !name.isEmpty, attrs["disabled"] == nil else { return nil }
                // A <button> submits unless it says otherwise.
                let type = (attrs["type"] ?? "submit").lowercased()
                return Input(name: decodeEntities(name), type: type == "submit" ? "submit" : "button",
                             value: decodeEntities(attrs["value"] ?? ""), checked: false)
            }
            return nil
        }
    }

    static func attributes(_ tagBody: String) -> [String: String] {
        var result: [String: String] = [:]
        let pattern = #"([a-zA-Z_:][-a-zA-Z0-9_:.]*)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+)))?"#
        for match in tagBody.regexMatches(pattern) {
            guard let key = match[1]?.lowercased(), result[key] == nil else { continue }
            result[key] = match[2] ?? match[3] ?? match[4] ?? ""
        }
        return result
    }

    private static func stripComments(_ html: String) -> String {
        // (?s): comments often span several lines.
        html.replacingOccurrences(of: #"(?s)<!--.*?-->"#, with: "", options: .regularExpression)
    }

    static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var out = s
        for match in s.regexMatches(#"&#(x?)([0-9a-fA-F]+);"#) {
            let isHex = !(match[1] ?? "").isEmpty
            if let digits = match[2], let code = UInt32(digits, radix: isHex ? 16 : 10),
               let scalar = Unicode.Scalar(code), let whole = match[0] {
                out = out.replacingOccurrences(of: whole, with: String(Character(scalar)))
            }
        }
        let named: [(String, String)] = [
            ("&quot;", "\""), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " "), ("&amp;", "&"),
        ]
        for (entity, char) in named {
            out = out.replacingOccurrences(of: entity, with: char)
        }
        return out
    }
}

extension String {
    /// All matches of `pattern` (case-insensitive, `.` matches newlines); each match lists its capture groups.
    func regexMatches(_ pattern: String) -> [[String?]] {
        guard let regex = try? NSRegularExpression(
            pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return [] }
        let ns = self as NSString
        return regex.matches(in: self, range: NSRange(location: 0, length: ns.length)).map { match in
            (0..<match.numberOfRanges).map { i in
                let range = match.range(at: i)
                return range.location == NSNotFound ? nil : ns.substring(with: range)
            }
        }
    }
}
