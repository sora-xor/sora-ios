/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import CoreData
import CommonWallet

extension CDDeposit: CoreDataCodable {
    enum CodingKeys: String, CodingKey {
        case depositTransactionId
        case transferTransactionId
        case timestamp
        case status
        case assetId
        case sender
        case receiver
        case receiverName
        case depositAmount
        case transferAmount
        case fees
        case note
    }

    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        identifier = try container.decode(String.self, forKey: .depositTransactionId)
        transferTransactionId = try container.decodeIfPresent(String.self, forKey: .transferTransactionId)
        timestamp = try container.decode(Int64.self, forKey: .timestamp)
        status = try container.decode(String.self, forKey: .status)
        assetId = try container.decode(String.self, forKey: .assetId)
        sender = try container.decode(String.self, forKey: .sender)
        receiver = try container.decode(String.self, forKey: .receiver)
        receiverName = try container.decodeIfPresent(String.self, forKey: .receiverName)
        depositAmount = try container.decode(String.self, forKey: .depositAmount)
        transferAmount = try container.decodeIfPresent(String.self, forKey: .transferAmount)

        let fees = try container.decode([Fee].self, forKey: .fees)
        self.fees = try JSONEncoder().encode(fees)

        note = try container.decodeIfPresent(String.self, forKey: .note)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(identifier, forKey: .depositTransactionId)
        try container.encodeIfPresent(transferTransactionId, forKey: .transferTransactionId)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(receiver, forKey: .receiver)
        try container.encodeIfPresent(receiverName, forKey: .receiverName)
        try container.encodeIfPresent(sender, forKey: .sender)
        try container.encodeIfPresent(assetId, forKey: .assetId)
        try container.encodeIfPresent(depositAmount, forKey: .depositAmount)
        try container.encodeIfPresent(transferAmount, forKey: .transferAmount)

        if let fees = fees {
            let feeList = try JSONDecoder().decode([Fee].self, from: fees)
            try container.encode(feeList, forKey: .fees)
        }

        try container.encodeIfPresent(note, forKey: .note)
    }
}
