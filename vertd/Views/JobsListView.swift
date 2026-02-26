import SwiftUI

struct JobsListView: View {
    @StateObject private var viewModel = JobsViewModel()

    @AppStorage(AppPreferences.serverURLKey) private var serverURLString = AppPreferences.defaultServerURL

    @State private var apiKey = ""

    var body: some View {
        NavigationStack {
            List {
                if viewModel.jobs.isEmpty {
                    ContentUnavailableView(
                        "No Jobs Yet",
                        systemImage: "tray",
                        description: Text("Uploaded files will appear here.")
                    )
                } else {
                    ForEach(viewModel.jobs) { job in
                        NavigationLink {
                            JobDetailView(
                                jobID: job.id,
                                initialJob: job,
                                serverURLString: serverURLString,
                                apiKey: apiKey
                            )
                        } label: {
                            JobRow(job: job)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if job.isPendingApproval {
                                Button("Convert") {
                                    Task { await viewModel.convert(jobID: job.id) }
                                }
                                .tint(.green)

                                Button("Skip", role: .destructive) {
                                    Task { await viewModel.skip(jobID: job.id) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Jobs")
            .refreshable {
                await viewModel.refreshNow()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    }
                }
            }
            .task {
                apiKey = (try? KeychainHelper.load(account: KeychainHelper.apiKeyAccount)) ?? ""
                viewModel.start(serverURLString: serverURLString, apiKey: apiKey)
            }
            .onDisappear {
                viewModel.stop()
            }
            .alert(
                "Jobs Error",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

private struct JobRow: View {
    let job: Job

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(job.file.name)
                    .font(.body)
                Text(job.file.s3Key ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(job.status.rawValue.capitalized)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(job.status.badgeColor.opacity(0.2))
                    .foregroundStyle(job.status.badgeColor)
                    .clipShape(Capsule())

                if job.status == .processing {
                    Text("\(Int(job.progress))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private extension JobStatus {
    var badgeColor: Color {
        switch self {
        case .pending:
            return .orange
        case .confirmed:
            return .blue
        case .processing:
            return .indigo
        case .completed:
            return .green
        case .failed:
            return .red
        case .skipped:
            return .gray
        }
    }
}

#Preview {
    JobsListView()
}
