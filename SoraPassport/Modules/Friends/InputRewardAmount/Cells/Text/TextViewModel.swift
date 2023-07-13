import CoreGraphics
import UIKit
import SoraUIKit

protocol TextViewModelProtocol {
    var title: String? { get }
    var textColor: SoramitsuColor? { get }
    var font: FontData? { get }
    var textAligment: NSTextAlignment { get }
}

struct TextViewModel: TextViewModelProtocol {
    var title: String?
    var textColor: SoramitsuColor?
    var font: FontData?
    var textAligment: NSTextAlignment

    init(title: String?,
         textColor: SoramitsuColor?,
         font: FontData?,
         textAligment: NSTextAlignment = .left) {
        self.title = title
        self.textColor = textColor
        self.font = font
        self.textAligment = textAligment
    }
}

extension TextViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return TextCell.reuseIdentifier
    }
}
