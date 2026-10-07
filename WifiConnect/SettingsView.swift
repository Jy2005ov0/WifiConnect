import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var studentID = Credentials.studentID
    @State private var password = Credentials.password
    @State private var showPassword = false
    @State private var detecting = false
    @State private var detectMessage: String?

    @AppStorage(SettingsKey.wifiName) private var wifiName = ""
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
                    Toggle("Set Login Page Manually", isOn: $useCustomPortal.animation())

                    if useCustomPortal {
                        LabeledField("URL", text: $loginURL, placeholder: "https://login.school.edu")
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
                    Text(detectMessage ?? "The login page is found automatically. If that doesn't work, join the school Wi-Fi and tap Detect Login Page, or fill it in manually.")
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
            loginURL = form.action.absoluteString
            method = form.method
            usernameField = form.usernameField ?? usernameField
            passwordField = form.passwordField ?? passwordField
            let known: Set<String> = [usernameField, passwordField]
            extraFields = form.inputs
                .filter { !known.contains($0.name) && $0.type == "hidden" }
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: "\n")
            useCustomPortal = true
            detectMessage = "Found the login page at \(form.action.host ?? "your school"). The details have been filled in above."
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
