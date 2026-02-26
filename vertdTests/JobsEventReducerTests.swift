import XCTest
@testable import vertd

final class JobsEventReducerTests: XCTestCase {
    func testAppliesProgressEventToMatchingJob() {
        var jobs = [Self.makeJob(id: "job1", status: .confirmed, progress: 0)]

        JobEventReducer.apply(event: .progress(jobID: "job1", progress: 34.2), to: &jobs)

        XCTAssertEqual(jobs[0].progress, 34.2)
        XCTAssertEqual(jobs[0].status, .processing)
    }

    func testAppliesSkippedEventToMatchingJob() {
        var jobs = [Self.makeJob(id: "job1", status: .pending, progress: 0)]

        JobEventReducer.apply(event: .skipped(jobID: "job1"), to: &jobs)

        XCTAssertEqual(jobs[0].status, .skipped)
    }

    func testInsertsNewFileEventAtTop() {
        var jobs = [Self.makeJob(id: "old", status: .pending, progress: 0)]
        let fresh = Self.makeJob(id: "fresh", status: .pending, progress: 0)

        JobEventReducer.apply(event: .newFile(fresh), to: &jobs)

        XCTAssertEqual(jobs.map(\.id), ["fresh", "old"])
    }

    private static func makeJob(id: String, status: JobStatus, progress: Double) -> Job {
        Job(
            id: id,
            status: status,
            file: FileInfo(name: "clip.mov", sizeBytes: 1200, path: nil, s3Key: "uploads/clip.mov"),
            createdAt: Date(),
            startedAt: nil,
            completedAt: nil,
            progress: progress,
            probe: nil,
            result: nil,
            telegramMessageID: nil
        )
    }
}
