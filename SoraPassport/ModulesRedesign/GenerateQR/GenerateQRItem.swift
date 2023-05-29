import Foundation
import SoraUIKit

final class GenerateQRItem: NSObject {
    
    let name: String
    let address: String
    let qrImage: UIImage?
    var shareHandler: (() -> Void)?
    var accountTapHandler: (() -> Void)?
    
    init(name: String, address: String, qrImage: UIImage?) {
        self.address = address
        self.qrImage = qrImage
        self.name = name
    }

}

extension GenerateQRItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { GenerateQRCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
