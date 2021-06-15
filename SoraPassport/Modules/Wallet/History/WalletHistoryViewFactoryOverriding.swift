import Foundation
import CommonWallet

final class WalletHistoryViewFactoryOverriding: HistoryViewFactoryOverriding {
    func createBackgroundView() -> BaseHistoryBackgroundView? {
        let backgroundView = WalletHistoryBackgroundView()
        return backgroundView
    }
}
