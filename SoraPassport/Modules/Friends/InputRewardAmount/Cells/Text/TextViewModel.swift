import CoreGraphics
import UIKit

protocol TextViewModelProtocol {
    var title: String? { get }
    var textColor: UIColor? { get }
    var font: UIFont? { get }
    var textAligment: NSTextAlignment { get }
}

struct TextViewModel: TextViewModelProtocol {
    var title: String?
    var textColor: UIColor?
    var font: UIFont?
    var textAligment: NSTextAlignment

    init(title: String?,
         textColor: UIColor?,
         font: UIFont?,
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
