import Foundation
import SoraUIKit

final class ExplorePoolListItem: NSObject {

    var viewModel: ExplorePoolViewModel
    var poolHandler: ((ExplorePoolViewModel?) -> Void)?

    init(viewModel: ExplorePoolViewModel) {
        self.viewModel = viewModel
    }
}

extension ExplorePoolListItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { ExplorePoolListCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        poolHandler?(viewModel)
    }
}

extension ExplorePoolListItem: ManagebleItem {
    var title: String {
        viewModel.title ?? ""
    }
}
