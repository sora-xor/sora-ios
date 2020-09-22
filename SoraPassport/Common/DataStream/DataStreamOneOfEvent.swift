import Foundation
import CommonWallet

enum DataStreamEventType: String, Codable {
    case operationStarted = "OperationStarted"
    case operationCompleted = "OperationCompleted"
    case operationFailed = "OperationFailed"
    case ethRegistrationStarted = "EthRegistrationStarted"
    case ethRegistrationCompleted = "EthRegistrationCompleted"
    case ethRegistrationFailed = "EthRegistrationFailed"
    case depositCompleted = "DepositOperationCompleted"
}

enum DataStreamOneOfEvent: Equatable {
    enum CodingKeys: String, CodingKey {
        case type = "event"
    }

    case operationStarted(_ event: OperationStartedStreamEvent)
    case ethRegistrationStarted(_ event: EthRegistrationStartedStreamEvent)
    case ethRegistrationCompleted(_ event: EthRegistrationCompletedStreamEvent)
    case ethRegistrationFailed(_ event: EthRegistrationFailedStreamEvent)
    case operationCompleted(_ event: OperationCompletedStreamEvent)
    case operationFailed(_ event: OperationFailedStreamEvent)
    case depositCompleted(_ event: DepositCompletedStreamEvent)
    case unknown(_ event: UnknownStreamEvent)
}

extension DataStreamOneOfEvent: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let typeValue = try container.decode(String.self, forKey: .type)

        guard let type = DataStreamEventType(rawValue: typeValue) else {
            self = .unknown(UnknownStreamEvent(type: typeValue))
            return
        }

        switch type {
        case .operationStarted:
            let event = try OperationStartedStreamEvent(from: decoder)
            self = .operationStarted(event)
        case .operationCompleted:
            let event = try OperationCompletedStreamEvent(from: decoder)
            self = .operationCompleted(event)
        case .operationFailed:
            let event = try OperationFailedStreamEvent(from: decoder)
            self = .operationFailed(event)
        case .ethRegistrationStarted:
            let event = try EthRegistrationStartedStreamEvent(from: decoder)
            self = .ethRegistrationStarted(event)
        case .ethRegistrationCompleted:
            let event = try EthRegistrationCompletedStreamEvent(from: decoder)
            self = .ethRegistrationCompleted(event)
        case .ethRegistrationFailed:
            let event = try EthRegistrationFailedStreamEvent(from: decoder)
            self = .ethRegistrationFailed(event)
        case .depositCompleted:
            let event = try DepositCompletedStreamEvent(from: decoder)
            self = .depositCompleted(event)
        }
    }

    func encode(to encoder: Encoder) throws {
        var type: DataStreamEventType?

        switch self {
        case .operationStarted(let event):
            try event.encode(to: encoder)
            type = .operationStarted
        case .ethRegistrationStarted(let event):
            try event.encode(to: encoder)
            type = .ethRegistrationStarted
        case .operationCompleted(let event):
            try event.encode(to: encoder)
            type = .operationCompleted
        case .operationFailed(let event):
            try event.encode(to: encoder)
            type = .operationFailed
        case .ethRegistrationCompleted(let event):
            try event.encode(to: encoder)
            type = .ethRegistrationCompleted
        case .ethRegistrationFailed(let event):
            try event.encode(to: encoder)
            type = .ethRegistrationFailed
        case .depositCompleted(let event):
            try event.encode(to: encoder)
            type = .depositCompleted
        case .unknown(let event):
            try event.encode(to: encoder)
        }

        if let type = type {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
        }
    }
}
