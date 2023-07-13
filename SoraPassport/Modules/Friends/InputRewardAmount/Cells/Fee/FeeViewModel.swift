import CoreGraphics
import UIKit
import SoraUIKit

protocol FeeViewModelProtocol {
    var title: String? { get }
    var feeAmount: String { get }
}

struct FeeViewModel: FeeViewModelProtocol {
    var title: String?
    var feeAmount: String

    init(title: String?,
         feeAmount: String) {
        self.title = title
        self.feeAmount = feeAmount
    }
}

extension FeeViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        return FeeCell.reuseIdentifier
    }
}

