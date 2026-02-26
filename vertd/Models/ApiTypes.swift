import Foundation

struct UploadURLRequest: Encodable {
    let filename: String
}

struct UploadURLResponse: Decodable {
    let url: URL
}

struct DownloadURLResponse: Decodable {
    let url: URL
}

struct JobsResponse: Decodable {
    let jobs: [Job]
}

struct JobActionResponse: Decodable {
    let status: String
    let job: Job
}

enum APIJSON {
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            for parser in DateParsers.all {
                if let date = parser(value) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date string: \(value)"
            )
        }
        return decoder
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(DateParsers.fractional.string(from: date))
        }
        return encoder
    }

    private enum DateParsers {
        static let all: [(String) -> Date?] = [
            { fractional.date(from: $0) },
            { standard.date(from: $0) },
            { microseconds.date(from: $0) },
        ]

        private static let standard: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
            return formatter
        }()

        private static let fractional: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTimeZone]
            return formatter
        }()

        private static let microseconds: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
            return formatter
        }()
    }
}
