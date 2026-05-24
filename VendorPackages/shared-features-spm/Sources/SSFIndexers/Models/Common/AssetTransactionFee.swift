import Foundation
import SSFModels

public struct AssetTransactionFee: Equatable {
    public let identifier: String
    public let assetId: String
    public let amount: SubstrateAmountDecimal?
    public let context: [String: String]?

    public init(
        identifier: String,
        assetId: String,
        amount: SubstrateAmountDecimal?,
        context: [String: String]? = nil
    ) {
        self.identifier = identifier
        self.assetId = assetId
        self.amount = amount
        self.context = context
    }
}
