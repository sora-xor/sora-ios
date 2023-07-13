import UIKit
import SoraUIKit

protocol ButtonViewModelProtocol: AnyObject {
    var title: String { get }
    var isEnabled: Bool { get }
    var delegate: ButtonCellDelegate { get }
    var titleColor: SoramitsuColor? { get }
    var backgroundColor: SoramitsuColor? { get }
}

class ButtonViewModel: ButtonViewModelProtocol {
    var title: String
    var titleColor: SoramitsuColor?
    var backgroundColor: SoramitsuColor?
    var isEnabled: Bool
    var delegate: ButtonCellDelegate

    init(title: String,
         isEnabled: Bool = true,
         titleColor: SoramitsuColor? = .bgSurface ,
         backgroundColor: SoramitsuColor? = .accentPrimary ,
         delegate: ButtonCellDelegate) {
        self.title = title
        self.isEnabled = isEnabled
        self.delegate = delegate
        self.titleColor = titleColor
        self.backgroundColor = backgroundColor
    }
}

extension ButtonViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        ButtonCell.reuseIdentifier
    }
}
