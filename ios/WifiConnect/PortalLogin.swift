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
    case noSignOutLink
    case stillSignedIn
    /// An automatic sign-in skipped a login page that doesn't look like the school's.
    case notSchoolPortal

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return String(localized: "Add your student ID and password in Settings first.")
        case .notOnWiFi:
            return String(localized: "Couldn't reach the Wi-Fi. Make sure you're connected to your school's network.")
        case .formNotFound:
            return String(localized: "Couldn't find a login form on your school's page. Set the login page manually in Settings.")
        case .invalidURL:
            return String(localized: "The custom login URL in Settings isn't valid.")
        case .network(let message):
            return String(localized: "The login page didn't respond: \(message)")
        case .stillOffline:
            return String(localized: "Signed in, but there's still no internet. Check your student ID and password.")
        case .noSignOutLink:
            return String(localized: "Your school's login page didn't show a sign-out link. You can add one in Settings › Login Page.")
        case .stillSignedIn:
            return String(localized: "The sign-out link didn't sign you out.")
        case .notSchoolPortal:
            return String(localized: "This Wi-Fi's login page doesn't look like your school's, so the app didn't sign in by itself. Tap the circle to sign in anyway.")
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
        session = Self.sharedSession
    }

    /// One session for the app's lifetime, so the login page's cookies are still there when
    /// signing out (and sessions aren't leaked).
    private static let sharedSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 25
        config.allowsCellularAccess = false // Always talk over Wi-Fi, never mobile data.
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        ]
        return URLSession(configuration: config, delegate: PortalTrust(), delegateQueue: nil)
    }()

    func logIn(
        studentID: String,
        password: String,
        settings: PortalSettings,
        trace: LoginTrace? = nil,
        allowPortal: ((URL) -> Bool)? = nil
    ) async throws -> LoginOutcome {
        guard !studentID.isEmpty, !password.isEmpty else { throw LoginError.missingCredentials }

        let result: ProbeResult
        do {
            result = try await probe()
        } catch {
            throw LoginError.notOnWiFi
        }
        guard case .portal(let page) = result else { return .alreadyOnline }
        trace?.portalURL = page.url
        if let allowPortal, !allowPortal(page.url) { throw LoginError.notSchoolPortal }

        let submission: FormSubmission
        if settings.useCustomPortal {
            // A path like "/login" is resolved against this building's login page, so one
            // setting works across blocks whose portals live at different addresses.
            let urlString = settings.loginURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !urlString.isEmpty,
                  let url = URL(string: urlString, relativeTo: page.url)?.absoluteURL,
                  url.scheme != nil, url.host != nil else {
                throw LoginError.invalidURL
            }
            let extra = settings.parsedExtraFields
            let overridden = Set(extra.map(\.name) + [settings.usernameField, settings.passwordField])
            // Hidden one-time tokens change every visit, so take fresh ones from the page when it has a form.
            var fields = (HTMLForm.loginForm(in: page.html, baseURL: page.url)?.inputs ?? [])
                .filter { $0.type == "hidden" && !overridden.contains($0.name) }
                .map { FormField(name: $0.name, value: $0.value) }
            fields += extra
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

        trace?.formAction = submission.url
        trace?.method = submission.method
        trace?.fieldNames = submission.fields.map(\.name)

        // The page after signing in is often slow or cut off as the network lets you through,
        // so a failure there isn't the final word: check whether you're online either way.
        var landing: Page?
        var submitError: Error?
        do {
            landing = try await submit(submission, referer: page.url)
        } catch {
            submitError = error
        }
        rememberSignOutLink(landing: landing, portal: page.url)

        // Give the network a moment to let us through, then confirm.
        for attempt in 0..<4 {
            if attempt > 0 { try? await Task.sleep(nanoseconds: 1_500_000_000) }
            if case .online? = try? await probe() { return .loggedIn }
        }
        throw submitError ?? LoginError.stillOffline
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

    /// Signs out using the link found after signing in, or the one set in Settings.
    func signOut() async throws {
        let defaults = UserDefaults.standard
        let base = defaults.string(forKey: SettingsKey.lastPortalURL).flatMap(URL.init(string:))
        let custom = (defaults.string(forKey: SettingsKey.signOutURL) ?? "").trimmingCharacters(in: .whitespaces)
        let url = custom.isEmpty
            ? defaults.string(forKey: SettingsKey.detectedSignOutURL).flatMap(URL.init(string:))
            : URL(string: custom, relativeTo: base)?.absoluteURL
        guard let url, url.host != nil else { throw LoginError.noSignOutLink }

        do {
            let (_, response) = try await session.data(from: url)
            // Some sign-out links are forms that only accept POST.
            if (response as? HTTPURLResponse)?.statusCode == 405 {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                _ = try await session.data(for: request)
            }
        } catch {
            throw LoginError.network(error.localizedDescription)
        }
        for attempt in 0..<3 {
            if attempt > 0 { try? await Task.sleep(nanoseconds: 1_000_000_000) }
            if case .portal? = try? await probe() { return }
        }
        throw LoginError.stillSignedIn
    }

    private func rememberSignOutLink(landing: Page?, portal: URL) {
        let defaults = UserDefaults.standard
        defaults.set(portal.absoluteString, forKey: SettingsKey.lastPortalURL)
        if let landing, let link = HTMLForm.signOutLink(in: landing.html, baseURL: landing.url) {
            defaults.set(link.absoluteString, forKey: SettingsKey.detectedSignOutURL)
        } else {
            // Don't keep a link from another building's login page.
            defaults.removeObject(forKey: SettingsKey.detectedSignOutURL)
        }
    }

    /// Sends the form and returns the page it led to, if any.
    private func submit(_ submission: FormSubmission, referer: URL) async throws -> Page? {
        let body = submission.fields
            .map { "\(Self.formEncode($0.name))=\(Self.formEncode($0.value))" }
            .joined(separator: "&")

        var request: URLRequest
        if submission.method.uppercased() == "GET" {
            // Like a browser, the form's fields replace the action's own query.
            var components = URLComponents(url: submission.url, resolvingAgainstBaseURL: false)
            components?.percentEncodedQuery = body
            request = URLRequest(url: components?.url ?? submission.url)
        } else {
            request = URLRequest(url: submission.url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(body.utf8)
        }
        request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")

        do {
            let (data, response) = try await session.data(for: request)
            let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
            return Page(url: response.url ?? submission.url, html: html)
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

/// Campus login pages in each building often sit on a bare private IP address with a certificate
/// that can't match it. Accept those, and only those: other sites are checked as usual.
final class PortalTrust: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              Self.isPrivateAddress(challenge.protectionSpace.host) else {
            return (.performDefaultHandling, nil)
        }
        return (.useCredential, URLCredential(trust: trust))
    }

    /// 10.0.0.0/8, 172.16.0.0/12 and 192.168.0.0/16.
    static func isPrivateAddress(_ host: String) -> Bool {
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }) else { return false }
        switch (parts[0], parts[1]) {
        case (10, _): return true
        case (172, 16...31): return true
        case (192, 168): return true
        default: return false
        }
    }
}
