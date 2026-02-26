import Foundation

protocol UploadAPIClient: Sendable {
    func getUploadUrl(filename: String) async throws -> URL
}

enum ApiClientError: Error, LocalizedError {
    case invalidEndpoint
    case invalidResponse
    case unauthorized
    case httpError(statusCode: Int, message: String)
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Invalid endpoint URL"
        case .invalidResponse:
            return "Unexpected server response"
        case .unauthorized:
            return "Unauthorized API request"
        case let .httpError(statusCode, message):
            return "Request failed with status \(statusCode): \(message)"
        case let .transport(error):
            return "Network error: \(error.localizedDescription)"
        case let .decoding(error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

actor ApiClient {
    struct Configuration: Equatable {
        let baseURL: URL
        let apiKey: String
    }

    private let configuration: Configuration
    private let session: URLSession

    init(configuration: Configuration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func getUploadUrl(filename: String) async throws -> URL {
        let requestBody = try APIJSON.encoder.encode(UploadURLRequest(filename: filename))
        let response: UploadURLResponse = try await send(path: "/api/upload-url", method: "POST", body: requestBody)
        return response.url
    }

    func listJobs() async throws -> [Job] {
        let response: JobsResponse = try await send(path: "/api/jobs", method: "GET")
        return response.jobs
    }

    func getJob(id: String) async throws -> Job {
        try await send(path: "/api/jobs/\(id)", method: "GET")
    }

    func convertJob(id: String) async throws -> Job {
        let response: JobActionResponse = try await send(path: "/api/jobs/\(id)/convert", method: "POST")
        return response.job
    }

    func skipJob(id: String) async throws -> Job {
        let response: JobActionResponse = try await send(path: "/api/jobs/\(id)/skip", method: "POST")
        return response.job
    }

    func getDownloadUrl(id: String) async throws -> URL {
        let response: DownloadURLResponse = try await send(path: "/api/jobs/\(id)/download-url", method: "GET")
        return response.url
    }

    func checkHealth() async throws -> Bool {
        let url = configuration.baseURL.appending(path: "health")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch {
            throw ApiClientError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ApiClientError.invalidResponse
        }

        return (200 ..< 300).contains(http.statusCode)
    }

    private func send<T: Decodable>(
        path: String,
        method: String,
        body: Data? = nil,
        responseType: T.Type = T.self
    ) async throws -> T {
        let request = try makeRequest(path: path, method: method, body: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ApiClientError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ApiClientError.invalidResponse
        }

        switch http.statusCode {
        case 200 ..< 300:
            break
        case 401:
            throw ApiClientError.unauthorized
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ApiClientError.httpError(statusCode: http.statusCode, message: message)
        }

        do {
            return try APIJSON.decoder.decode(responseType, from: data)
        } catch {
            throw ApiClientError.decoding(error)
        }
    }

    private func makeRequest(path: String, method: String, body: Data?) throws -> URLRequest {
        guard let url = resolvedURL(path: path) else {
            throw ApiClientError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return request
    }

    private func resolvedURL(path: String) -> URL? {
        if path.hasPrefix("/") {
            return configuration.baseURL.appending(path: String(path.dropFirst()))
        }
        return configuration.baseURL.appending(path: path)
    }
}

extension ApiClient: UploadAPIClient {}
