import Foundation
import SoraUIKit

final class ExploreAssetListItem: NSObject {

    var viewModel: ExploreAssetViewModel
    var assetHandler: ((String?) -> Void)?

    init(viewModel: ExploreAssetViewModel) {
        self.viewModel = viewModel
    }
}

extension ExploreAssetListItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { ExploreAssetListCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        assetHandler?(viewModel.assetId)
    }
}

extension ExploreAssetListItem: ManagebleItem {
    var title: String {
        viewModel.title ?? ""
    }
}
