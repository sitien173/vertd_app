import Foundation

enum JobStatus: String, Codable, CaseIterable {
    case pending
    case confirmed
    case processing
    case completed
    case failed
    case skipped
}

struct FileInfo: Codable, Equatable {
    let name: String
    let sizeBytes: Int
    let path: String?
    let s3Key: String?

    enum CodingKeys: String, CodingKey {
        case name
        case sizeBytes = "size_bytes"
        case path
        case s3Key = "s3_key"
    }
}

struct ProbeResult: Codable, Equatable {
    let durationSeconds: Double
    let videoCodec: String
    let audioCodec: String
    let width: Int
    let height: Int
    let frameCount: Int
    let frameRate: Double

    enum CodingKeys: String, CodingKey {
        case durationSeconds = "duration_seconds"
        case videoCodec = "video_codec"
        case audioCodec = "audio_codec"
        case width
        case height
        case frameCount = "frame_count"
        case frameRate = "frame_rate"
    }
}

struct TranscodeResult: Codable, Equatable {
    let outputPath: String?
    let outputSizeBytes: Int
    let durationSeconds: Double
    let error: String
    let outputS3Key: String

    enum CodingKeys: String, CodingKey {
        case outputPath = "output_path"
        case outputSizeBytes = "output_size_bytes"
        case durationSeconds = "duration_seconds"
        case error
        case outputS3Key = "output_s3_key"
    }
}

struct Job: Codable, Equatable, Identifiable {
    let id: String
    var status: JobStatus
    let file: FileInfo
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var progress: Double
    var probe: ProbeResult?
    var result: TranscodeResult?
    var telegramMessageID: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case file
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case progress
        case probe
        case result
        case telegramMessageID = "telegram_message_id"
    }

    var isPendingApproval: Bool {
        status == .pending
    }

    var isTerminal: Bool {
        switch status {
        case .completed, .failed, .skipped:
            return true
        default:
            return false
        }
    }
}
