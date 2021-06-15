import UIKit
import CommonWallet
import SoraUI
import SoraFoundation

final class WalletAccountHeaderView: UICollectionViewCell {
    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet weak var scanButton: RoundedButton!
    @IBOutlet weak var moreButton: RoundedButton!

    var viewModel: WalletViewModelProtocol?

    override func awakeFromNib() {
        super.awakeFromNib()

        localizationManager = LocalizationManager.shared
        titleLabel.font = UIFont.styled(for: .display1)

        scanButton.addTarget(self, action: #selector(scanTouch), for: .touchUpInside)
    }

    @objc func scanTouch() {
        try? viewModel?.command?.execute()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel = nil
    }

    private func setupLocalization() {
        let languages = localizationManager?.preferredLocalizations
        titleLabel.text = R.string.localizable.walletTitle(preferredLanguages: languages)
    }
}

extension WalletAccountHeaderView: Localizable {
    func applyLocalization() {
        setupLocalization()

        if superview != nil {
            setNeedsLayout()
        }
    }
}

extension WalletAccountHeaderView: WalletViewProtocol {

    func bind(viewModel: WalletViewModelProtocol) {
        self.viewModel = viewModel
    }
}
