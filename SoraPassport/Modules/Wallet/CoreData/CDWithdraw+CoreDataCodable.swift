import Foundation
import RobinHood
import CoreData
import CommonWallet

extension CDWithdraw: CoreDataCodable {
    enum CodingKeys: String, CodingKey {
        case intentTransactionId
        case confirmationTransactionId
        case transferTransactionId
        case timestamp
        case status
        case assetId
        case sender
        case receiver
        case receiverName
        case withdrawAmount
        case transferAmount
        case fees
    }

    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        identifier = try container.decode(String.self, forKey: .intentTransactionId)
        confirmationTransactionId = try container.decodeIfPresent(String.self,
                                                                  forKey: .confirmationTransactionId)
        transferTransactionId = try container.decodeIfPresent(String.self, forKey: .transferTransactionId)
        timestamp = try container.decode(Int64.self, forKey: .timestamp)
        status = try container.decode(String.self, forKey: .status)
        assetId = try container.decode(String.self, forKey: .assetId)
        sender = try container.decode(String.self, forKey: .sender)
        receiver = try container.decode(String.self, forKey: .receiver)
        receiverName = try container.decodeIfPresent(String.self, forKey: .receiverName)
        withdrawAmount = try container.decode(String.self, forKey: .withdrawAmount)
        transferAmount = try container.decodeIfPresent(String.self, forKey: .transferAmount)

        let fees = try container.decode([Fee].self, forKey: .fees)
        self.fees = try JSONEncoder().encode(fees)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(identifier, forKey: .intentTransactionId)
        try container.encodeIfPresent(confirmationTransactionId, forKey: .confirmationTransactionId)
        try container.encodeIfPresent(transferTransactionId, forKey: .transferTransactionId)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(receiver, forKey: .receiver)
        try container.encodeIfPresent(receiverName, forKey: .receiverName)
        try container.encodeIfPresent(sender, forKey: .sender)
        try container.encodeIfPresent(assetId, forKey: .assetId)
        try container.encodeIfPresent(withdrawAmount, forKey: .withdrawAmount)
        try container.encodeIfPresent(transferAmount, forKey: .transferAmount)

        if let fees = fees {
            let feeList = try JSONDecoder().decode([Fee].self, from: fees)
            try container.encode(feeList, forKey: .fees)
        }
    }
}
