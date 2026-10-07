import Foundation

enum LoginOutcome {
    case alreadyOnline
    case loggedIn
}

enum LoginError: LocalizedError {
    case missingCredentials
    case notOnWiFi
    case formNotFound
    case invalidURL
    case network(String)
    case stillOffline

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Add your student ID and password in Settings first."
        case .notOnWiFi:
            return "Couldn't reach the Wi-Fi. Make sure you're connected to your school's network."
        case .formNotFound:
            return "Couldn't find a login form on your school's page. Set the login page manually in Settings."
        case .invalidURL:
            return "The custom login URL in Settings isn't valid."
        case .network(let message):
            return "The login page didn't respond: \(message)"
        case .stillOffline:
            return "Signed in, but there's still no internet. Check your student ID and password."
        }
    }
}

/// Detects the campus captive portal and signs in to it.
struct PortalLogin {
    struct Page {
        var url: URL
        var html: String
    }

    enum ProbeResult {
        case online
        case portal(Page)
    }

    /// The page iOS itself uses to detect Wi-Fi login screens.
    static var probeURL: URL {
        #if DEBUG
        // Lets the end-to-end test point the app at a mock login page.
        if let override = UserDefaults.standard.string(forKey: "testProbeURL"), let url = URL(string: override) {
            return url
        }
        #endif
        return URL(string: "http://captive.apple.com/hotspot-detect.html")!
    }

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 25
        config.allowsCellularAccess = false // Always talk over Wi-Fi, never mobile data.
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        ]
        session = URLSession(configuration: config)
    }

    func logIn(studentID: String, password: String, settings: PortalSettings) async throws -> LoginOutcome {
        guard !studentID.isEmpty, !password.isEmpty else { throw LoginError.missingCredentials }

        let result: ProbeResult
        do {
            result = try await probe()
        } catch {
            throw LoginError.notOnWiFi
        }
        guard case .portal(let page) = result else { return .alreadyOnline }

        let submission: FormSubmission
        if settings.useCustomPortal {
            let urlString = settings.loginURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: urlString), url.scheme != nil, url.host != nil else {
                throw LoginError.invalidURL
            }
            var fields = settings.parsedExtraFields
            fields.append(FormField(name: settings.usernameField, value: studentID))
            fields.append(FormField(name: settings.passwordField, value: password))
            submission = FormSubmission(url: url, method: settings.method, fields: fields)
        } else {
            guard let form = HTMLForm.loginForm(in: page.html, baseURL: page.url),
                  let filled = form.submission(username: studentID, password: password) else {
                throw LoginError.formNotFound
            }
            submission = filled
        }

        try await submit(submission, referer: page.url)

        // Give the network a moment to let us through, then confirm.
        for attempt in 0..<4 {
            if attempt > 0 { try? await Task.sleep(nanoseconds: 1_500_000_000) }
            if case .online? = try? await probe() { return .loggedIn }
        }
        throw LoginError.stillOffline
    }

    /// Finds the login form on the current network, for filling in the manual settings.
    func detectForm() async throws -> HTMLForm? {
        let result: ProbeResult
        do {
            result = try await probe()
        } catch {
            throw LoginError.notOnWiFi
        }
        guard case .portal(let page) = result else { return nil }
        guard let form = HTMLForm.loginForm(in: page.html, baseURL: page.url) else {
            throw LoginError.formNotFound
        }
        return form
    }

    func probe() async throws -> ProbeResult {
        var page = try await fetch(Self.probeURL)
        if page.url.host == Self.probeURL.host,
           page.html.range(of: "<body>success</body>", options: .caseInsensitive) != nil {
            return .online
        }
        // Some portals bounce through a page or two of meta/JavaScript redirects.
        for _ in 0..<3 {
            guard HTMLForm.loginForm(in: page.html, baseURL: page.url) == nil,
                  let next = HTMLForm.clientRedirect(in: page.html, baseURL: page.url) else { break }
            page = try await fetch(next)
        }
        return .portal(page)
    }

    private func fetch(_ url: URL) async throws -> Page {
        let (data, response) = try await session.data(from: url)
        let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        return Page(url: response.url ?? url, html: html)
    }

    private func submit(_ submission: FormSubmission, referer: URL) async throws {
        let body = submission.fields
            .map { "\(Self.formEncode($0.name))=\(Self.formEncode($0.value))" }
            .joined(separator: "&")

        var request: URLRequest
        if submission.method.uppercased() == "GET" {
            var components = URLComponents(url: submission.url, resolvingAgainstBaseURL: false)
            let existing = components?.percentEncodedQuery.map { $0 + "&" } ?? ""
            components?.percentEncodedQuery = existing + body
            request = URLRequest(url: components?.url ?? submission.url)
        } else {
            request = URLRequest(url: submission.url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(body.utf8)
        }
        request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")

        do {
            _ = try await session.data(for: request)
        } catch {
            throw LoginError.network(error.localizedDescription)
        }
    }

    private static let formAllowed = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._*"
    )

    private static func formEncode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: formAllowed) ?? s
    }
}
