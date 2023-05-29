import Foundation
import SoraUIKit
import CommonWallet

final class AssetIdItem: NSObject {

    var assetId: String
    var tapHandler: (() -> Void)?

    init(assetId: String, tapHandler: (() -> Void)?) {
        self.assetId = assetId
        self.tapHandler = tapHandler
    }
}

extension AssetIdItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { AssetIdCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        tapHandler?()
    }
}
