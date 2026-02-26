import XCTest
@testable import vertd

final class WebSocketEventDecodingTests: XCTestCase {
    func testDecodesProgressEvent() throws {
        let json = """
        {
          "type": "progress",
          "job_id": "job42",
          "progress": 66.7
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let event = try WebSocketEvent.decode(from: data, decoder: APIJSON.decoder)

        guard case let .progress(jobID, progress) = event else {
            return XCTFail("Expected .progress event")
        }
        XCTAssertEqual(jobID, "job42")
        XCTAssertEqual(progress, 66.7)
    }

    func testDecodesCompletedEvent() throws {
        let json = """
        {
          "type": "completed",
          "job": {
            "id": "job7",
            "status": "completed",
            "file": {
              "name": "clip.mov",
              "size_bytes": 2048,
              "path": null,
              "s3_key": "uploads/clip.mov"
            },
            "created_at": "2026-02-26T09:12:00+00:00",
            "started_at": "2026-02-26T09:13:00+00:00",
            "completed_at": "2026-02-26T09:14:00+00:00",
            "progress": 100,
            "probe": null,
            "result": {
              "output_path": "clip.mp4",
              "output_size_bytes": 1000,
              "duration_seconds": 120.0,
              "error": "",
              "output_s3_key": "processed/clip.mp4"
            },
            "telegram_message_id": null
          }
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let event = try WebSocketEvent.decode(from: data, decoder: APIJSON.decoder)

        guard case let .completed(job) = event else {
            return XCTFail("Expected .completed event")
        }
        XCTAssertEqual(job.id, "job7")
        XCTAssertEqual(job.status, .completed)
    }
}
