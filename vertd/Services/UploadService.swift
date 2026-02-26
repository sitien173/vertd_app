import Foundation

protocol UploadingService {
    func upload(fileURL: URL, to uploadURL: URL, progress: @escaping (Double) -> Void) async throws
}

final class UploadService: NSObject, UploadingService {
    private final class UploadOperation {
        let progressHandler: (Double) -> Void
        let continuation: CheckedContinuation<Void, Error>

        init(progressHandler: @escaping (Double) -> Void, continuation: CheckedContinuation<Void, Error>) {
            self.progressHandler = progressHandler
            self.continuation = continuation
        }
    }

    private let lock = NSLock()
    private var operations: [Int: UploadOperation] = [:]

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.vertd.upload.\(UUID().uuidString)")
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 60 * 60
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    func upload(fileURL: URL, to uploadURL: URL, progress: @escaping (Double) -> Void) async throws {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"

        try await withCheckedThrowingContinuation { continuation in
            let task = session.uploadTask(with: request, fromFile: fileURL)
            let operation = UploadOperation(progressHandler: progress, continuation: continuation)
            store(operation: operation, for: task.taskIdentifier)
            task.resume()
        }
    }

    private func store(operation: UploadOperation, for taskID: Int) {
        lock.lock()
        operations[taskID] = operation
        lock.unlock()
    }

    private func takeOperation(for taskID: Int) -> UploadOperation? {
        lock.lock()
        defer { lock.unlock() }
        return operations.removeValue(forKey: taskID)
    }

    private func getOperation(for taskID: Int) -> UploadOperation? {
        lock.lock()
        defer { lock.unlock() }
        return operations[taskID]
    }
}

extension UploadService: URLSessionTaskDelegate, URLSessionDataDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        _ = session
        guard totalBytesExpectedToSend > 0,
              let operation = getOperation(for: task.taskIdentifier)
        else {
            return
        }

        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        operation.progressHandler(progress)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        _ = session
        guard let operation = takeOperation(for: task.taskIdentifier) else {
            return
        }

        if let error {
            operation.continuation.resume(throwing: error)
            return
        }

        guard let response = task.response as? HTTPURLResponse else {
            operation.continuation.resume(throwing: URLError(.badServerResponse))
            return
        }

        guard (200 ..< 300).contains(response.statusCode) else {
            operation.continuation.resume(throwing: URLError(.badServerResponse))
            return
        }

        operation.progressHandler(1.0)
        operation.continuation.resume()
    }
}
