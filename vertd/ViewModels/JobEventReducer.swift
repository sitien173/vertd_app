import Foundation

enum JobEventReducer {
    static func apply(event: WebSocketEvent, to jobs: inout [Job]) {
        switch event {
        case let .newFile(job):
            upsert(job, in: &jobs, insertAtTop: true)

        case let .completed(job), let .failed(job):
            upsert(job, in: &jobs)

        case let .progress(jobID, progress):
            guard let index = jobs.firstIndex(where: { $0.id == jobID }) else { return }
            jobs[index].progress = progress
            if jobs[index].status == .confirmed || jobs[index].status == .pending {
                jobs[index].status = .processing
            }

        case let .skipped(jobID):
            guard let index = jobs.firstIndex(where: { $0.id == jobID }) else { return }
            jobs[index].status = .skipped
        }
    }

    private static func upsert(_ job: Job, in jobs: inout [Job], insertAtTop: Bool = false) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index] = job
            if insertAtTop {
                let updated = jobs.remove(at: index)
                jobs.insert(updated, at: 0)
            }
            return
        }

        if insertAtTop {
            jobs.insert(job, at: 0)
        } else {
            jobs.append(job)
        }
    }
}
