/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import CommonWallet
import SoraUI
import SoraFoundation

final class WalletAccountHeaderView: UICollectionViewCell {
    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet private(set) var helpButton: RoundedButton!

    var viewModel: WalletViewModelProtocol?

    override func awakeFromNib() {
        super.awakeFromNib()

        localizationManager = LocalizationManager.shared
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel = nil
    }

    private func setupLocalization() {
        let languages = localizationManager?.preferredLocalizations
        titleLabel.text = R.string.localizable.walletTitle(preferredLanguages: languages)
    }

    @IBAction private func actionHelp() {
        if let headerViewModel = viewModel as? WalletHeaderViewModel {
            headerViewModel.presentHelp()
        }
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
