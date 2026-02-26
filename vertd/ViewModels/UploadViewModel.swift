import Foundation

@MainActor
final class UploadViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case preparing
        case uploading
        case uploaded
        case failed(message: String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var uploadProgress: Double = 0

    private let uploadService: UploadingService
    private let apiClientFactory: (URL, String) -> any UploadAPIClient

    init(
        apiClientFactory: @escaping (URL, String) -> any UploadAPIClient = { baseURL, apiKey in
            ApiClient(configuration: .init(baseURL: baseURL, apiKey: apiKey))
        },
        uploadService: UploadingService = UploadService()
    ) {
        self.apiClientFactory = apiClientFactory
        self.uploadService = uploadService
    }

    func upload(fileURL: URL, fileName: String, serverURLString: String, apiKey: String) async {
        guard let baseURL = URL(string: serverURLString), !serverURLString.isEmpty else {
            phase = .failed(message: "Please set a valid server URL in Settings.")
            return
        }

        guard !apiKey.isEmpty else {
            phase = .failed(message: "Please add an API key in Settings.")
            return
        }

        let client = apiClientFactory(baseURL, apiKey)
        phase = .preparing
        uploadProgress = 0

        do {
            let uploadURL = try await client.getUploadUrl(filename: fileName)
            phase = .uploading

            try await uploadService.upload(fileURL: fileURL, to: uploadURL) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.uploadProgress = progress
                }
            }

            uploadProgress = 1
            phase = .uploaded
        } catch {
            phase = .failed(message: error.localizedDescription)
        }
    }

    func reset() {
        phase = .idle
        uploadProgress = 0
    }
}
