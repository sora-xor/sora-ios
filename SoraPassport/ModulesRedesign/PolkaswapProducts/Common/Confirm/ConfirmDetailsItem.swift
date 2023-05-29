import Foundation
import SoraUIKit

final class ConfirmDetailsItem: NSObject {

    var detailViewModels: [DetailViewModel] = []

    init(detailViewModels: [DetailViewModel]) {
        self.detailViewModels = detailViewModels
    }
}

extension ConfirmDetailsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { ConfirmDetailsCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
