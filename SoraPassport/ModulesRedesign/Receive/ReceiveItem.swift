import Foundation
import SoraUIKit

final class ReceiveItem: NSObject {
    
    let name: String
    let address: String
    let qrImage: UIImage?
    let sendAssetViewModel: SendAssetViewModel?
    var shareHandler: (() -> Void)?
    var accountTapHandler: (() -> Void)?
    
    init(name: String, address: String, qrImage: UIImage?, sendAssetViewModel: SendAssetViewModel? = nil) {
        self.address = address
        self.qrImage = qrImage
        self.name = name
        self.sendAssetViewModel = sendAssetViewModel
    }

}

extension ReceiveItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { ReceiveCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
