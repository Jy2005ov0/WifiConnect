import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var studentID = Credentials.studentID
    @State private var password = Credentials.password
    @State private var showPassword = false
    @State private var detecting = false
    @State private var detectMessage: String?
    @State private var language = AppLanguage.current
    @State private var showLanguageNotice = false

    @AppStorage(SettingsKey.wifiName) private var wifiName = SettingsKey.defaultWifiName
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system
    @AppStorage(SettingsKey.showWelcome) private var showWelcome = true
    @AppStorage(SettingsKey.staySignedIn) private var staySignedIn = true
    @AppStorage(SettingsKey.notifyOnConnect) private var notifyOnConnect = true
    @AppStorage(SettingsKey.requireUnlock) private var requireUnlock = false
    @AppStorage(SettingsKey.useCustomPortal) private var useCustomPortal = false
    @AppStorage(SettingsKey.loginURL) private var loginURL = ""
    @AppStorage(SettingsKey.method) private var method = "POST"
    @AppStorage(SettingsKey.usernameField) private var usernameField = "username"
    @AppStorage(SettingsKey.passwordField) private var passwordField = "password"
    @AppStorage(SettingsKey.extraFields) private var extraFields = ""
    @AppStorage(SettingsKey.signOutURL) private var signOutURL = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Named for VoiceOver, which otherwise only reads the placeholder until you type.
                    TextField("Student ID", text: $studentID)
                        .accessibilityLabel("Student ID")
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
                        .accessibilityLabel("Password")

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(showPassword ? String(localized: "Hide password") : String(localized: "Show password"))
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Saved in your iPhone's Keychain and only sent to your school's login page.")
                }

                Section {
                    TextField("Network Name", text: $wifiName)
                        .accessibilityLabel("Network Name")
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
                    Toggle(isOn: Binding(
                        get: { requireUnlock },
                        set: { newValue in
                            // Turning the lock on or off needs the same unlock.
                            Task {
                                if await AppLock.authenticate(reason: String(localized: "Confirm it's you to change the app lock.")) {
                                    requireUnlock = newValue
                                }
                            }
                        }
                    )) {
                        Text("Require \(AppLock.methodName)")
                    }
                } header: {
                    Text("Security")
                } footer: {
                    Text("Asks for \(AppLock.methodName) before showing Settings, where your password is saved.")
                }

                Section {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Label("Sign-In History", systemImage: "clock.arrow.circlepath")
                    }
                    NavigationLink {
                        ShareSetupView()
                    } label: {
                        Label("Share Setup with Friends", systemImage: "qrcode")
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
                    Toggle("Show When Opening the App", isOn: $showWelcome)
                } header: {
                    Text("Welcome Page")
                } footer: {
                    Text("The page with the clock that you swipe up. Turn it off to go straight to the Wi-Fi circle.")
                }

                Section {
                    Picker("Language", selection: $language) {
                        Text("Same as Phone").tag(AppLanguage.system)
                        ForEach(AppLanguage.allCases.filter { $0 != .system }) { option in
                            Text(verbatim: option.nativeName).tag(option)
                        }
                    }
                    .onChange(of: language) {
                        language.apply()
                        showLanguageNotice = true
                    }
                }
                .alert("Close and reopen WiFi Connect to use the new language.", isPresented: $showLanguageNotice) {
                    Button("OK") {}
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

                    LabeledField("Sign-Out URL", text: $signOutURL, placeholder: "/logout")

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
                    if let detectMessage {
                        Text(verbatim: detectMessage)
                    } else {
                        Text("The login page is found automatically, even when each building uses a different address. If that doesn't work, join the school Wi-Fi and tap Detect Login Page, or fill it in manually. Enter just the path, like /login, so it works in every building.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveAndClose() }
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: studentID) {
                Credentials.studentID = studentID.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .onChange(of: password) {
                Credentials.password = password
            }
            // Also when the sheet is swiped down.
            .onDisappear(perform: saveAccount)
        }
    }

    /// Saves what's in the boxes, so nothing typed is lost however Settings closes.
    private func saveAccount() {
        Credentials.studentID = studentID.trimmingCharacters(in: .whitespacesAndNewlines)
        Credentials.password = password
    }

    private func saveAndClose() {
        // Finish typing first, so the last character reaches the box's value, then save it.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.async {
            saveAccount()
            dismiss()
        }
    }

    private func detect() async {
        detecting = true
        defer { detecting = false }
        do {
            guard let form = try await PortalLogin().detectForm() else {
                detectMessage = String(localized: "You're already online, so there's no login page to detect. Try again right after joining the school Wi-Fi.")
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
            let host = form.action.host ?? String(localized: "your school")
            detectMessage = useCustomPortal
                ? String(localized: "Found the login page at \(host). The details above have been updated.")
                : String(localized: "Found the login page at \(host). Automatic sign-in works here and in other buildings, so there's nothing to set up.")
        } catch {
            detectMessage = error.localizedDescription
        }
    }
}

private struct LabeledField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    let placeholder: String

    init(_ label: LocalizedStringKey, text: Binding<String>, placeholder: String) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        LabeledContent(label) {
            TextField(placeholder, text: $text)
                .accessibilityLabel(label)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }
}

#Preview {
    SettingsView()
}
