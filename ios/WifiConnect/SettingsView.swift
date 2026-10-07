import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var studentID = Credentials.studentID
    @State private var password = Credentials.password
    @State private var showPassword = false
    @State private var detecting = false
    @State private var detectMessage: String?

    @AppStorage(SettingsKey.wifiName) private var wifiName = SettingsKey.defaultWifiName
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system
    @AppStorage(SettingsKey.staySignedIn) private var staySignedIn = true
    @AppStorage(SettingsKey.notifyOnConnect) private var notifyOnConnect = true
    @AppStorage(SettingsKey.useCustomPortal) private var useCustomPortal = false
    @AppStorage(SettingsKey.loginURL) private var loginURL = ""
    @AppStorage(SettingsKey.method) private var method = "POST"
    @AppStorage(SettingsKey.usernameField) private var usernameField = "username"
    @AppStorage(SettingsKey.passwordField) private var passwordField = "password"
    @AppStorage(SettingsKey.extraFields) private var extraFields = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Student ID", text: $studentID)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack {
                        Group {
                            if showPassword {
                                TextField("Password", text: $password)
                            } else {
                                SecureField("Password", text: $password)
                            }
                        }
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(showPassword ? "Hide Password" : "Show Password")
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Saved in your iPhone's Keychain and only sent to your school's login page.")
                }

                Section {
                    TextField("Network Name", text: $wifiName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("School Wi-Fi")
                } footer: {
                    Text("The Wi-Fi name you join on campus. Used in the auto-connect guide.")
                }

                Section {
                    Toggle("Stay Signed In", isOn: $staySignedIn)
                        .onChange(of: staySignedIn) { KeepAlive.schedule() }
                    Toggle("Notify When Connected", isOn: $notifyOnConnect)
                } header: {
                    Text("Automatic Sign-In")
                } footer: {
                    Text("Stay Signed In checks in the background and signs you back in if the campus Wi-Fi logs you out. iOS decides exactly when it runs. Notifications appear when the app signs you in on its own.")
                }

                Section {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Label("Sign-In History", systemImage: "clock.arrow.circlepath")
                    }
                } header: {
                    Text("Help")
                }

                Section {
                    AppearancePicker(selection: $appearance)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                } header: {
                    Text("Appearance")
                }

                Section {
                    Toggle("Set Login Page Manually", isOn: $useCustomPortal.animation())

                    if useCustomPortal {
                        LabeledField("URL or Path", text: $loginURL, placeholder: "/login")
                            .keyboardType(.URL)
                        Picker("Method", selection: $method) {
                            Text("POST").tag("POST")
                            Text("GET").tag("GET")
                        }
                        LabeledField("ID Field", text: $usernameField, placeholder: "username")
                        LabeledField("Password Field", text: $passwordField, placeholder: "password")
                        TextField("Extra fields, one name=value per line", text: $extraFields, axis: .vertical)
                            .lineLimit(2...5)
                            .font(.callout.monospaced())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Button {
                        Task { await detect() }
                    } label: {
                        HStack {
                            Text("Detect Login Page")
                            Spacer()
                            if detecting { ProgressView() }
                        }
                    }
                    .disabled(detecting)
                } header: {
                    Text("Login Page")
                } footer: {
                    Text(detectMessage ?? "The login page is found automatically, even when each building uses a different address. If that doesn't work, join the school Wi-Fi and tap Detect Login Page, or fill it in manually. Enter just the path, like /login, so it works in every building.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: studentID) {
                Credentials.studentID = studentID.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .onChange(of: password) {
                Credentials.password = password
            }
        }
    }

    private func detect() async {
        detecting = true
        defer { detecting = false }
        do {
            guard let form = try await PortalLogin().detectForm() else {
                detectMessage = "You're already online, so there's no login page to detect. Try again right after joining the school Wi-Fi."
                return
            }
            // Save a path rather than this building's address, so it also works in other blocks.
            if form.action.host == form.pageURL.host {
                var path = form.action.path.isEmpty ? "/" : form.action.path
                if let query = form.action.query { path += "?" + query }
                loginURL = path
            } else {
                loginURL = form.action.absoluteString
            }
            method = form.method
            usernameField = form.usernameField ?? usernameField
            passwordField = form.passwordField ?? passwordField
            let host = form.action.host ?? "your school"
            detectMessage = useCustomPortal
                ? "Found the login page at \(host). The details above have been updated."
                : "Found the login page at \(host). Automatic sign-in works here and in other buildings, so there's nothing to set up."
        } catch {
            detectMessage = error.localizedDescription
        }
    }
}

private struct LabeledField: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    init(_ label: String, text: Binding<String>, placeholder: String) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        LabeledContent(label) {
            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }
}

#Preview {
    SettingsView()
}
