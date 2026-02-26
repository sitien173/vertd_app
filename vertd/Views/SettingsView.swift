import SwiftUI

struct SettingsView: View {
    @AppStorage(AppPreferences.serverURLKey) private var serverURLString = AppPreferences.defaultServerURL

    @State private var apiKey = ""
    @State private var isSaving = false
    @State private var isTesting = false
    @State private var statusMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    TextField("Server URL", text: $serverURLString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    SecureField("API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Button {
                        Task { await saveSettings() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving)

                    Button {
                        Task { await verifyConnection() }
                    } label: {
                        if isTesting {
                            ProgressView()
                        } else {
                            Text("Verify")
                        }
                    }
                    .disabled(isTesting)
                }

                if !statusMessage.isEmpty {
                    Section("Status") {
                        Text(statusMessage)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                apiKey = (try? KeychainHelper.load(account: KeychainHelper.apiKeyAccount)) ?? ""
            }
        }
    }

    private func saveSettings() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let trimmed = serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard URL(string: trimmed) != nil else {
                statusMessage = "Server URL is invalid."
                return
            }

            serverURLString = trimmed

            let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedAPIKey.isEmpty {
                try KeychainHelper.delete(account: KeychainHelper.apiKeyAccount)
            } else {
                try KeychainHelper.save(trimmedAPIKey, account: KeychainHelper.apiKeyAccount)
            }

            statusMessage = "Settings saved."
        } catch {
            statusMessage = "Failed to save settings: \(error.localizedDescription)"
        }
    }

    private func verifyConnection() async {
        isTesting = true
        defer { isTesting = false }

        guard let baseURL = URL(string: serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            statusMessage = "Server URL is invalid."
            return
        }

        do {
            let client = ApiClient(configuration: .init(baseURL: baseURL, apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines)))
            let healthy = try await client.checkHealth()
            statusMessage = healthy ? "Connection OK." : "Server returned unhealthy status."
        } catch {
            statusMessage = "Verification failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    SettingsView()
}
