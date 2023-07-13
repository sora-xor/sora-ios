import Foundation
import SoraUIKit
import CommonWallet
import RobinHood

final class StakedItem: NSObject {
    var title: String
    var detailsViewModel: [DetailViewModel] = []

    init(title: String, detailsViewModel: [DetailViewModel]) {
        self.title = title
        self.detailsViewModel = detailsViewModel
    }
}

extension StakedItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { StakedCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
