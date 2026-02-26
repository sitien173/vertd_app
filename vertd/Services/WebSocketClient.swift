import Combine
import Foundation

enum WebSocketEvent: Equatable {
    case newFile(Job)
    case progress(jobID: String, progress: Double)
    case completed(Job)
    case failed(Job)
    case skipped(jobID: String)

    static func decode(from data: Data, decoder: JSONDecoder = APIJSON.decoder) throws -> WebSocketEvent {
        let envelope = try decoder.decode(EventEnvelope.self, from: data)

        switch envelope.type {
        case "new_file":
            guard let job = envelope.job else { throw WebSocketClientError.invalidPayload }
            return .newFile(job)
        case "progress":
            guard let jobID = envelope.jobID, let progress = envelope.progress else {
                throw WebSocketClientError.invalidPayload
            }
            return .progress(jobID: jobID, progress: progress)
        case "completed":
            guard let job = envelope.job else { throw WebSocketClientError.invalidPayload }
            return .completed(job)
        case "failed":
            guard let job = envelope.job else { throw WebSocketClientError.invalidPayload }
            return .failed(job)
        case "skipped":
            guard let jobID = envelope.jobID else { throw WebSocketClientError.invalidPayload }
            return .skipped(jobID: jobID)
        default:
            throw WebSocketClientError.unknownEventType(envelope.type)
        }
    }

    private struct EventEnvelope: Decodable {
        let type: String
        let job: Job?
        let jobID: String?
        let progress: Double?

        enum CodingKeys: String, CodingKey {
            case type
            case job
            case jobID = "job_id"
            case progress
        }
    }
}

enum WebSocketClientError: Error {
    case invalidURL
    case invalidPayload
    case unknownEventType(String)
}

@MainActor
final class WebSocketClient: ObservableObject {
    @Published private(set) var isConnected = false

    let events = PassthroughSubject<WebSocketEvent, Never>()

    private let session: URLSession
    private let decoder: JSONDecoder

    private var socketTask: URLSessionWebSocketTask?
    private var receiveLoopTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var shouldReconnect = false
    private var context: ConnectionContext?

    init(session: URLSession = .shared, decoder: JSONDecoder = APIJSON.decoder) {
        self.session = session
        self.decoder = decoder
    }

    func connect(baseURL: URL, apiKey: String) {
        context = ConnectionContext(baseURL: baseURL, apiKey: apiKey)
        shouldReconnect = true
        reconnectTask?.cancel()
        startSocket()
    }

    func disconnect() {
        shouldReconnect = false
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveLoopTask?.cancel()
        receiveLoopTask = nil
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
        isConnected = false
    }

    private func startSocket() {
        guard let context else { return }

        do {
            let wsURL = try Self.makeWebSocketURL(from: context.baseURL, apiKey: context.apiKey)
            let task = session.webSocketTask(with: wsURL)
            socketTask?.cancel(with: .goingAway, reason: nil)
            socketTask = task
            task.resume()
            reconnectAttempt = 0
            isConnected = true

            receiveLoopTask?.cancel()
            receiveLoopTask = Task { [weak self] in
                guard let self else { return }
                await self.receiveLoop(for: task)
            }
        } catch {
            isConnected = false
            scheduleReconnect()
        }
    }

    private func receiveLoop(for task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case let .string(text):
                    guard let data = text.data(using: .utf8) else { continue }
                    do {
                        try emitEvent(from: data)
                    } catch {
                        continue
                    }
                case let .data(data):
                    do {
                        try emitEvent(from: data)
                    } catch {
                        continue
                    }
                @unknown default:
                    continue
                }
            } catch {
                isConnected = false
                scheduleReconnect()
                return
            }
        }
    }

    private func emitEvent(from data: Data) throws {
        let event = try WebSocketEvent.decode(from: data, decoder: decoder)
        events.send(event)
    }

    private func scheduleReconnect() {
        guard shouldReconnect else { return }

        reconnectTask?.cancel()
        let delaySeconds = min(pow(2.0, Double(reconnectAttempt)), 30.0)
        reconnectAttempt += 1

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            guard let self, !Task.isCancelled, self.shouldReconnect else { return }
            self.startSocket()
        }
    }

    private static func makeWebSocketURL(from baseURL: URL, apiKey: String) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw WebSocketClientError.invalidURL
        }

        switch components.scheme?.lowercased() {
        case "https":
            components.scheme = "wss"
        case "http", "ws":
            components.scheme = "ws"
        case "wss":
            components.scheme = "wss"
        default:
            throw WebSocketClientError.invalidURL
        }

        var path = components.path
        if path.hasSuffix("/") {
            path.removeLast()
        }
        components.path = path.isEmpty ? "/api/ws" : "\(path)/api/ws"
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]

        guard let finalURL = components.url else {
            throw WebSocketClientError.invalidURL
        }

        return finalURL
    }

    private struct ConnectionContext {
        let baseURL: URL
        let apiKey: String
    }
}
