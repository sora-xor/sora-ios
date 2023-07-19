import CoreGraphics
import UIKit

protocol ReferrerLinkViewModelProtocol {
    var isEnabled: Bool { get}
    var delegate: ReferrerLinkCellDelegate? { get }
}

class ReferrerLinkViewModel: ReferrerLinkViewModelProtocol {
    var isEnabled: Bool
    var delegate: ReferrerLinkCellDelegate?

    init(isEnabled: Bool = false,
         delegate: ReferrerLinkCellDelegate?) {
        self.isEnabled = isEnabled
        self.delegate = delegate
    }
}

extension ReferrerLinkViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return ReferrerLinkCell.reuseIdentifier
    }
}

