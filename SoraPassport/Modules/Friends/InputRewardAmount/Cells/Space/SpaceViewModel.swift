import CoreGraphics
import UIKit

protocol SpaceViewModelProtocol {
    var height: CGFloat { get }
    var backgroundColor: UIColor { get }
}

struct SpaceViewModel: SpaceViewModelProtocol {
    var height: CGFloat
    var backgroundColor: UIColor

    init(height: CGFloat, backgroundColor: UIColor) {
        self.height = height
        self.backgroundColor = backgroundColor
    }
}

extension SpaceViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return SpaceCell.reuseIdentifier
    }
}

