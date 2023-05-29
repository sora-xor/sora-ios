import Foundation
import SoraUIKit

final class ActivityDetailsItem: NSObject {

    var detailViewModels: [ActivityDetailViewModel] = []
    var copyToClipboardHander: ((String) -> Void)?

    init(detailViewModels: [ActivityDetailViewModel]) {
        self.detailViewModels = detailViewModels
    }
}

extension ActivityDetailsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { ActivityDetailsCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
