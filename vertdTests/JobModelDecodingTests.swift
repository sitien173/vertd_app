import XCTest
@testable import vertd

final class JobModelDecodingTests: XCTestCase {
    func testDecodesJobFromBackendPayload() throws {
        let json = """
        {
          "id": "abc123",
          "status": "processing",
          "file": {
            "name": "clip.mov",
            "size_bytes": 2048,
            "path": null,
            "s3_key": "uploads/clip.mov"
          },
          "created_at": "2026-02-26T09:12:00.123456+00:00",
          "started_at": "2026-02-26T09:12:10.123456+00:00",
          "completed_at": null,
          "progress": 42.5,
          "probe": {
            "duration_seconds": 120.0,
            "video_codec": "h264",
            "audio_codec": "aac",
            "width": 1920,
            "height": 1080,
            "frame_count": 3600,
            "frame_rate": 30.0
          },
          "result": null,
          "telegram_message_id": 99
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let job = try APIJSON.decoder.decode(Job.self, from: data)

        XCTAssertEqual(job.id, "abc123")
        XCTAssertEqual(job.status, .processing)
        XCTAssertEqual(job.file.name, "clip.mov")
        XCTAssertEqual(job.file.s3Key, "uploads/clip.mov")
        XCTAssertEqual(job.progress, 42.5)
        XCTAssertEqual(job.telegramMessageID, 99)
        XCTAssertEqual(job.probe?.videoCodec, "h264")
    }

    func testDecodesJobsEnvelope() throws {
        let json = """
        {
          "jobs": [
            {
              "id": "job1",
              "status": "pending",
              "file": {
                "name": "a.mov",
                "size_bytes": 100,
                "path": null,
                "s3_key": "uploads/a.mov"
              },
              "created_at": "2026-02-26T09:12:00+00:00",
              "started_at": null,
              "completed_at": null,
              "progress": 0,
              "probe": null,
              "result": null,
              "telegram_message_id": null
            }
          ]
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try APIJSON.decoder.decode(JobsResponse.self, from: data)
        XCTAssertEqual(response.jobs.count, 1)
        XCTAssertEqual(response.jobs[0].id, "job1")
    }
}
