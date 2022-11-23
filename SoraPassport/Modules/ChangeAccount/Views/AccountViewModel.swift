import UIKit

protocol AccountViewModelProtocol {
    var iconImage: UIImage? { get }
    var title: String { get }
    var isSelected: Bool { get set }
}

struct AccountViewModel: AccountViewModelProtocol {
    var iconImage: UIImage?
    var title: String
    var isSelected: Bool

    init(by title: String, isSelected: Bool, iconImage: UIImage?) {
        self.title = title
        self.isSelected = isSelected
        self.iconImage = iconImage
    }
}
