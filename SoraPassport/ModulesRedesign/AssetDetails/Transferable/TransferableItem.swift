import Foundation
import SoraUIKit

final class TransferableItem: NSObject {

    var assetInfo: AssetInfo
    var fiat: String
    var balance: Amount
    var isNeedTransferable: Bool = true
    var actionHandler: ((TransferableActionType) -> Void)?
    var frozenAmount: Amount?
    var frozenFiatAmount: String?

    init(assetInfo: AssetInfo, fiat: String, balance: Amount) {
        self.assetInfo = assetInfo
        self.fiat = fiat
        self.balance = balance
    }
}

extension TransferableItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { TransferableCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
