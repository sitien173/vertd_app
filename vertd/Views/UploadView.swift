import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct UploadView: View {
    @StateObject private var viewModel = UploadViewModel()

    @AppStorage(AppPreferences.serverURLKey) private var serverURLString = AppPreferences.defaultServerURL

    @State private var apiKey = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showFileImporter = false

    var body: some View {
        NavigationStack {
            List {
                Section("Source") {
                    PhotosPicker(selection: $selectedPhoto, matching: .videos) {
                        Label("Pick From Photos", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Pick File", systemImage: "folder")
                    }
                }

                Section("Upload Progress") {
                    ProgressView(value: viewModel.uploadProgress)
                    Text(progressLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if case let .failed(message) = viewModel.phase {
                    Section("Error") {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Upload")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") {
                        viewModel.reset()
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.movie, .mpeg4Movie, .video],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
            .onChange(of: selectedPhoto) { newValue in
                guard let newValue else { return }
                Task {
                    await uploadFromPhotoItem(newValue)
                }
            }
            .task {
                apiKey = (try? KeychainHelper.load(account: KeychainHelper.apiKeyAccount)) ?? ""
            }
        }
    }

    private var progressLabel: String {
        switch viewModel.phase {
        case .idle:
            return "Select a video to start upload."
        case .preparing:
            return "Requesting upload URL..."
        case .uploading:
            return "Uploading \(Int(viewModel.uploadProgress * 100))%"
        case .uploaded:
            return "Upload complete. The backend will detect and queue the file."
        case let .failed(message):
            return message
        }
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else {
            return
        }

        Task {
            let granted = url.startAccessingSecurityScopedResource()
            defer {
                if granted {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            await upload(fileURL: url, fileName: url.lastPathComponent)
        }
    }

    private func uploadFromPhotoItem(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                return
            }

            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "mov"
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("upload-\(UUID().uuidString).\(ext)")
            try data.write(to: tempURL, options: .atomic)

            await upload(fileURL: tempURL, fileName: tempURL.lastPathComponent)
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            await MainActor.run {
                viewModel.reset()
            }
        }
    }

    private func upload(fileURL: URL, fileName: String) async {
        await viewModel.upload(
            fileURL: fileURL,
            fileName: fileName,
            serverURLString: serverURLString,
            apiKey: apiKey
        )
    }
}

#Preview {
    UploadView()
}
