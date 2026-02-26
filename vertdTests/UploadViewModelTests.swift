import XCTest
@testable import vertd

final class UploadViewModelTests: XCTestCase {
    func testRejectsMissingServerURL() async {
        let viewModel = UploadViewModel(
            apiClientFactory: { _, _ in FatalUploadApiClient() },
            uploadService: FakeUploadService()
        )

        await viewModel.upload(
            fileURL: URL(fileURLWithPath: "/tmp/video.mov"),
            fileName: "video.mov",
            serverURLString: "",
            apiKey: "token"
        )

        if case .failed = viewModel.phase {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected failed phase")
        }
    }

    func testMarksSuccessAfterUploadCompletes() async {
        let apiClient = FakeUploadApiClient(url: URL(string: "https://example.com/upload")!)
        let uploadService = FakeUploadService()

        let viewModel = UploadViewModel(
            apiClientFactory: { _, _ in apiClient },
            uploadService: uploadService
        )

        await viewModel.upload(
            fileURL: URL(fileURLWithPath: "/tmp/video.mov"),
            fileName: "video.mov",
            serverURLString: "https://api.example.com",
            apiKey: "token"
        )

        XCTAssertEqual(uploadService.lastUploadedURL?.absoluteString, "https://example.com/upload")
        if case .uploaded = viewModel.phase {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected uploaded phase")
        }
    }
}

private actor FakeUploadApiClient: UploadAPIClient {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func getUploadUrl(filename: String) async throws -> URL {
        url
    }
}

private actor FatalUploadApiClient: UploadAPIClient {
    func getUploadUrl(filename: String) async throws -> URL {
        throw URLError(.badURL)
    }
}

private final class FakeUploadService: UploadingService {
    private(set) var lastUploadedURL: URL?

    func upload(fileURL: URL, to uploadURL: URL, progress: @escaping (Double) -> Void) async throws {
        _ = fileURL
        lastUploadedURL = uploadURL
        progress(1.0)
    }
}
