import Foundation
import SoraUIKit
import CommonWallet

final class RecentActivityItem: NSObject {

    var historyViewModels: [ActivityContentViewModel]
    var openActivityDetailsHandler: ((String) -> Void)?
    var openFullActivityHandler: (() -> Void)?

    init(historyViewModels: [ActivityContentViewModel]) {
        self.historyViewModels = historyViewModels
    }
}

extension RecentActivityItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { RecentActivityCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
