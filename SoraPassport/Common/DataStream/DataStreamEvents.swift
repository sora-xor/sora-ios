import Foundation

struct UnknownStreamEvent: Codable, Equatable {
    let type: String
}

struct EthRegistrationStartedStreamEvent: Codable, Equatable {
    let operationId: String
    let timestamp: Int64
    let address: String
}

struct EthRegistrationCompletedStreamEvent: Codable, Equatable {
    let operationId: String
    let timestamp: Int64
}

struct EthRegistrationFailedStreamEvent: Codable, Equatable {
    let operationId: String
    let timestamp: Int64
    let reason: String?
}

struct OperationStartedStreamEvent: Codable, Equatable {
    let timestamp: Int64
    let operationId: String
    let type: String
    let peerId: String
    let peerName: String
    let amount: String
    let details: String?
    let fee: String?

}

struct OperationCompletedStreamEvent: Codable, Equatable {
    let timestamp: Int64
    let operationId: String
    let type: String
    let peerId: String
    let peerName: String
    let amount: String
    let details: String?
    let fee: String?
}

struct OperationFailedStreamEvent: Codable, Equatable {
    let timestamp: Int64
    let operationId: String
    let type: String?
    let peerId: String?
    let peerName: String?
    let amount: String?
    let details: String?
    let fee: String?
    let reason: String?
}

struct DepositCompletedStreamEvent: Codable, Equatable {
    let timestamp: Int64
    let operationId: String
    let assetId: String
    let amount: String
    let sidechainHash: String
}
