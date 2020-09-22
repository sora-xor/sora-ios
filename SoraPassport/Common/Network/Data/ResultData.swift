import Foundation
import SoraDocuments

enum ResultDataError: Error {
    case missingStatusField
    case unexpectedNumberOfFields
}

struct StatusData: Decodable {
    var code: String
    var message: String

    var isSuccess: Bool {
        return code == "OK"
    }
}

struct StatusResultData: Decodable {
    var status: StatusData
}

struct ResultData<ResultType> where ResultType: Decodable {
    var status: StatusData
    var result: ResultType?
}

extension ResultData: Decodable {
    enum CodingKeys: String, CodingKey {
        case status
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DocumentDynamicCodingKey.self)

        guard container.allKeys.count > 0, container.allKeys.count < 3 else {
            throw ResultDataError.unexpectedNumberOfFields
        }

        guard let statusKey = DocumentDynamicCodingKey(stringValue: CodingKeys.status.rawValue) else {
            throw ResultDataError.missingStatusField
        }

        status = try container.decode(StatusData.self, forKey: statusKey)

        if let resultKey = container.allKeys.first(where: { $0.stringValue != CodingKeys.status.stringValue }) {
            result = try container.decode(ResultType.self, forKey: resultKey)
        }
    }
}

struct MultifieldResultData<ResultType> where ResultType: Decodable {
    var status: StatusData
    var result: ResultType
}

extension MultifieldResultData: Decodable {
    enum CodingKeys: String, CodingKey {
        case status
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DocumentDynamicCodingKey.self)

        guard let statusKey = DocumentDynamicCodingKey(stringValue: CodingKeys.status.rawValue) else {
            throw ResultDataError.missingStatusField
        }

        status = try container.decode(StatusData.self, forKey: statusKey)

        result = try ResultType(from: decoder)
    }
}

struct OptionalMultifieldResultData<ResultType> where ResultType: Decodable {
    var status: StatusData
    var result: ResultType?
}

extension OptionalMultifieldResultData: Decodable {
    enum CodingKeys: String, CodingKey {
        case status
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DocumentDynamicCodingKey.self)

        guard let statusKey = DocumentDynamicCodingKey(stringValue: CodingKeys.status.rawValue) else {
            throw ResultDataError.missingStatusField
        }

        status = try container.decode(StatusData.self, forKey: statusKey)

        if status.isSuccess {
            result = try ResultType(from: decoder)
        } else {
            result = nil
        }
    }
}
