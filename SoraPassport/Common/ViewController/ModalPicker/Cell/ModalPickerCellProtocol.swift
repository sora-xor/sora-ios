import Foundation
import UIKit

protocol ModalPickerCellProtocol {
    associatedtype Model

    var checkmarked: Bool { get set }

    var toggle: UISwitch? { get }

    func bind(model: Model)
}

extension ModalPickerCellProtocol {
    var toggle: UISwitch? { nil }
}
