import Foundation
import CommonWallet

class EmptyUICollectionViewCell: UICollectionViewCell, WalletViewProtocol {
    public var viewModel: WalletViewModelProtocol? {
        nil
    }

    public func bind(viewModel: WalletViewModelProtocol) {
        
    }
}
