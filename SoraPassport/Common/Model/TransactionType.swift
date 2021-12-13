import Foundation

enum TransactionType: String, CaseIterable {
    case incoming = "INCOMING"
    case outgoing = "OUTGOING"
    case reward = "REWARD"
    case slash = "SLASH"
    case swap = "SWAP"
    case extrinsic = "EXTRINSIC"
}
