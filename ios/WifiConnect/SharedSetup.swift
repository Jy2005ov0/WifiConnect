import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// The settings a classmate needs: Wi-Fi name and login page details. Never the student ID or password.
struct SharedSetup: Codable, Identifiable {
    var v = 1
    var wifiName: String
    var useCustomPortal: Bool
    var loginURL: String
    var method: String
    var usernameField: String
    var passwordField: String
    var extraFields: String
    var signOutURL: String

    var id: String { url.absoluteString }

    static func current() -> SharedSetup {
        let d = UserDefaults.standard
        let s = PortalSettings.load()
        return SharedSetup(
            wifiName: d.string(forKey: SettingsKey.wifiName) ?? SettingsKey.defaultWifiName,
            useCustomPortal: s.useCustomPortal,
            loginURL: s.loginURL,
            method: s.method,
            usernameField: s.usernameField,
            passwordField: s.passwordField,
            extraFields: s.extraFields,
            signOutURL: d.string(forKey: SettingsKey.signOutURL) ?? ""
        )
    }

    func apply() {
        let d = UserDefaults.standard
        d.set(wifiName, forKey: SettingsKey.wifiName)
        d.set(useCustomPortal, forKey: SettingsKey.useCustomPortal)
        d.set(loginURL, forKey: SettingsKey.loginURL)
        d.set(method, forKey: SettingsKey.method)
        d.set(usernameField, forKey: SettingsKey.usernameField)
        d.set(passwordField, forKey: SettingsKey.passwordField)
        d.set(extraFields, forKey: SettingsKey.extraFields)
        d.set(signOutURL, forKey: SettingsKey.signOutURL)
    }

    /// wificonnect://setup?d=<base64url JSON>. Scanning it with the Camera opens the app.
    var url: URL {
        let data = (try? JSONEncoder().encode(self)) ?? Data()
        let encoded = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return URL(string: "wificonnect://setup?d=\(encoded)")!
    }

    init(wifiName: String, useCustomPortal: Bool, loginURL: String, method: String,
         usernameField: String, passwordField: String, extraFields: String, signOutURL: String) {
        self.wifiName = wifiName
        self.useCustomPortal = useCustomPortal
        self.loginURL = loginURL
        self.method = method
        self.usernameField = usernameField
        self.passwordField = passwordField
        self.extraFields = extraFields
        self.signOutURL = signOutURL
    }

    init?(url: URL) {
        guard url.scheme == "wificonnect", url.host == "setup",
              let encoded = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "d" })?.value else { return nil }
        var base64 = encoded.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64),
              let setup = try? JSONDecoder().decode(SharedSetup.self, from: data) else { return nil }
        // Only a path (resolved against the campus login page) or a private campus address,
        // so a link can never send your password to an outside server.
        guard Self.staysOnCampus(setup.loginURL), Self.staysOnCampus(setup.signOutURL) else { return nil }
        self = setup
    }

    private static func staysOnCampus(_ address: String) -> Bool {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), url.scheme != nil || trimmed.hasPrefix("//") else {
            return true
        }
        return PortalTrust.isPrivateAddress(url.host ?? "")
    }

    func qrCode() -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// Settings › Share Setup: a QR code for classmates.
struct ShareSetupView: View {
    private let setup = SharedSetup.current()

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    if let image = setup.qrCode() {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 240)
                            .padding(16)
                            .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .accessibilityLabel("QR code")
                    }
                    Text("Ask a classmate to scan this with their phone's camera. WiFi Connect opens with your Wi-Fi and login page settings filled in.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section {
                ShareLink(item: setup.url) {
                    Label("Share Setup Link", systemImage: "square.and.arrow.up")
                }
            } footer: {
                Text("Only the Wi-Fi name and login page settings are shared. Never your student ID or password.")
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Share Setup")
        .navigationBarTitleDisplayMode(.inline)
    }
}
