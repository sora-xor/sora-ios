import Foundation
import RobinHood
import CoreData
import CommonWallet

extension CDTransfer: CoreDataCodable {
    enum CodingKeys: String, CodingKey {
        case transactionId
        case category
        case status
        case timestamp
        case receiver
        case receiverName
        case sender
        case assetId
        case amount
        case fees
        case note
    }

    func populate(from data: TransferOperationData) throws {
        identifier = data.transactionId
        category = data.category.rawValue
        status = data.status.rawValue
        timestamp = data.timestamp
        receiver = data.receiver
        receiverName = data.receiverName
        sender = data.sender
        assetId = data.assetId
        amount = data.amount.stringValue
        note = data.note

        fees = try JSONEncoder().encode(data.fees)
    }

    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        identifier = try container.decode(String.self, forKey: .transactionId)
        category = try container.decode(String.self, forKey: .category)
        status = try container.decode(String.self, forKey: .status)
        timestamp = try container.decode(Int64.self, forKey: .timestamp)
        receiver = try container.decode(String.self, forKey: .receiver)
        receiverName = try container.decodeIfPresent(String.self, forKey: .receiverName)
        sender = try container.decode(String.self, forKey: .sender)
        assetId = try container.decode(String.self, forKey: .assetId)
        amount = try container.decode(String.self, forKey: .amount)

        let fees = try container.decode([Fee].self, forKey: .fees)
        self.fees = try JSONEncoder().encode(fees)

        note = try container.decodeIfPresent(String.self, forKey: .note)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(identifier, forKey: .transactionId)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(receiver, forKey: .receiver)
        try container.encodeIfPresent(receiverName, forKey: .receiverName)
        try container.encodeIfPresent(sender, forKey: .sender)
        try container.encodeIfPresent(assetId, forKey: .assetId)
        try container.encodeIfPresent(amount, forKey: .amount)
        try container.encodeIfPresent(note, forKey: .note)

        if let fees = fees {
            let feeList = try JSONDecoder().decode([Fee].self, from: fees)
            try container.encode(feeList, forKey: .fees)
        }
    }
}
