import SwiftUI

struct JobDetailView: View {
    let jobID: String
    let serverURLString: String
    let apiKey: String

    @State private var job: Job
    @State private var isLoading = false
    @State private var errorMessage: String?

    @Environment(\.openURL) private var openURL

    init(jobID: String, initialJob: Job, serverURLString: String, apiKey: String) {
        self.jobID = jobID
        self.serverURLString = serverURLString
        self.apiKey = apiKey
        _job = State(initialValue: initialJob)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    ProgressRing(progress: ringProgress)
                        .frame(width: 96, height: 96)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(job.file.name)
                            .font(.headline)
                        Text(job.status.rawValue.capitalized)
                            .foregroundStyle(.secondary)
                        if job.status == .processing {
                            Text("\(Int(job.progress))%")
                                .font(.title3.weight(.semibold))
                        }
                    }
                }

                GroupBox("File") {
                    DetailRow(label: "Size", value: ByteCountFormatter.string(fromByteCount: Int64(job.file.sizeBytes), countStyle: .file))
                    DetailRow(label: "S3 Key", value: job.file.s3Key ?? "-")
                }

                if let probe = job.probe {
                    GroupBox("Probe") {
                        DetailRow(label: "Video", value: probe.videoCodec)
                        DetailRow(label: "Audio", value: probe.audioCodec)
                        DetailRow(label: "Resolution", value: "\(probe.width)x\(probe.height)")
                        DetailRow(label: "Duration", value: "\(Int(probe.durationSeconds))s")
                    }
                }

                if let result = job.result {
                    GroupBox("Result") {
                        DetailRow(label: "Output", value: result.outputPath ?? "-")
                        DetailRow(label: "Output Size", value: ByteCountFormatter.string(fromByteCount: Int64(result.outputSizeBytes), countStyle: .file))
                        DetailRow(label: "Duration", value: "\(Int(result.durationSeconds))s")

                        if !result.error.isEmpty {
                            Text(result.error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }

                if job.status == .completed {
                    Button {
                        Task { await downloadOutput() }
                    } label: {
                        Label("Download Output", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .navigationTitle("Job Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isLoading {
                    ProgressView()
                }
            }
        }
        .task(id: jobID) {
            await pollingLoop()
        }
    }

    private var ringProgress: Double {
        switch job.status {
        case .completed:
            return 1
        case .failed, .skipped:
            return max(min(job.progress / 100, 1), 0)
        default:
            return max(min(job.progress / 100, 1), 0.02)
        }
    }

    private func makeClient() -> ApiClient? {
        guard let baseURL = URL(string: serverURLString), !apiKey.isEmpty else {
            return nil
        }

        return ApiClient(configuration: .init(baseURL: baseURL, apiKey: apiKey))
    }

    private func pollingLoop() async {
        while !Task.isCancelled {
            await refreshJob()
            if job.isTerminal {
                return
            }

            do {
                try await Task.sleep(nanoseconds: 3_000_000_000)
            } catch {
                return
            }
        }
    }

    private func refreshJob() async {
        guard let client = makeClient() else {
            errorMessage = "Missing connection settings."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await client.getJob(id: jobID)
            job = fetched
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func downloadOutput() async {
        guard let client = makeClient() else {
            errorMessage = "Missing connection settings."
            return
        }

        do {
            let url = try await client.getDownloadUrl(id: jobID)
            _ = openURL(url)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 2)
    }
}

private struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 10)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            Text("\(Int(progress * 100))%")
                .font(.caption.weight(.semibold))
        }
    }
}
