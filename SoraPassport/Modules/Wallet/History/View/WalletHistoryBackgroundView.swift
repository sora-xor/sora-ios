import Foundation
import CommonWallet
import SoraUI

final class WalletHistoryBackgroundView: RoundedView {
    let minimizedSideLength: CGFloat = 10.0
}

extension WalletHistoryBackgroundView: HistoryBackgroundViewProtocol {
    func applyFullscreen(progress: CGFloat) {

    }

    func apply(style: HistoryViewStyleProtocol) {}

//    func applyFullscreen(progress: CGFloat) {
//        sideLength = minimizedSideLength * progress
//    }
}
