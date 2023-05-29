import Foundation
import SoraUIKit

final class WordNumberItem: NSObject {
    var currentStage: Int = 0
    var index: Int = 0
    var variants: [String] = []
    var tryHandler: ((String) -> Void)?
}

extension WordNumberItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { WordNumberCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
