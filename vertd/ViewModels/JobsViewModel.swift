import Combine
import Foundation

@MainActor
final class JobsViewModel: ObservableObject {
    @Published private(set) var jobs: [Job] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let webSocketClient: WebSocketClient
    private var eventCancellable: AnyCancellable?
    private var pollingTask: Task<Void, Never>?
    private var apiClient: ApiClient?
    private var currentContext: Context?

    init(webSocketClient: WebSocketClient = WebSocketClient()) {
        self.webSocketClient = webSocketClient
    }

    func start(serverURLString: String, apiKey: String) {
        guard let baseURL = URL(string: serverURLString), !serverURLString.isEmpty else {
            errorMessage = "Set a valid server URL in Settings."
            return
        }

        guard !apiKey.isEmpty else {
            errorMessage = "Set an API key in Settings."
            return
        }

        let context = Context(baseURL: baseURL, apiKey: apiKey)
        if currentContext == context {
            return
        }

        stop()

        currentContext = context
        apiClient = ApiClient(configuration: .init(baseURL: baseURL, apiKey: apiKey))

        eventCancellable = webSocketClient.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                JobEventReducer.apply(event: event, to: &self.jobs)
            }

        webSocketClient.connect(baseURL: baseURL, apiKey: apiKey)

        pollingTask = Task { [weak self] in
            guard let self else { return }
            await self.pollJobs()
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        eventCancellable?.cancel()
        eventCancellable = nil
        webSocketClient.disconnect()
    }

    func refreshNow() async {
        await fetchJobs()
    }

    func convert(jobID: String) async {
        guard let apiClient else { return }
        do {
            let updated = try await apiClient.convertJob(id: jobID)
            upsert(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func skip(jobID: String) async {
        guard let apiClient else { return }
        do {
            let updated = try await apiClient.skipJob(id: jobID)
            upsert(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pollJobs() async {
        while !Task.isCancelled {
            await fetchJobs()
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000)
            } catch {
                return
            }
        }
    }

    private func fetchJobs() async {
        guard let apiClient else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let serverJobs = try await apiClient.listJobs()
            jobs = serverJobs.sorted { $0.createdAt > $1.createdAt }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func upsert(_ job: Job) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index] = job
        } else {
            jobs.insert(job, at: 0)
        }
    }

    private struct Context: Equatable {
        let baseURL: URL
        let apiKey: String
    }
}
