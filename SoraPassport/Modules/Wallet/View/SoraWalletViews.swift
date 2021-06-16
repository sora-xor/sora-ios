/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import CommonWallet
import SoraFoundation
import SoraUI
import Foundation


final class InvisibleHeaderView: BaseOperationDefinitionHeaderView {
    func bind(viewModel: MultilineTitleIconViewModelProtocol) {

    }
}

final class SoraAssetView: BaseSelectedAssetView, WalletFormBordering {

    @IBOutlet private(set) var assetTitle: UILabel!
    @IBOutlet private(set) var assetLabel: UILabel!
    @IBOutlet private(set) var assetIcon: UIImageView!

    @IBOutlet private(set) var assetIdTitle: UILabel!
    @IBOutlet private(set) var assetIdLabel: GrayCopyButton!
    @IBAction private func buttonTap() {
        UIPasteboard.general.string = fullText
    }
    private var fullText: String?

    @IBOutlet private(set) var balanceTitle: UILabel!
    @IBOutlet private(set) var balanceLabel: UILabel!

    weak var delegate: SelectedAssetViewDelegate?

    var activated: Bool = false

    var borderType: BorderType = .bottom

    override func awakeFromNib() {
        self.assetTitle.font = UIFont.styled(for: .paragraph2)
        self.assetLabel.font = UIFont.styled(for: .paragraph2)
        self.assetIdTitle.font = UIFont.styled(for: .paragraph2)
        self.balanceTitle.font = UIFont.styled(for: .paragraph2)
        self.balanceLabel.font = UIFont.styled(for: .paragraph2)

    }

    func bind(viewModel: AssetSelectionViewModelProtocol) {
        self.assetIcon.image = viewModel.icon
        self.assetLabel.text = viewModel.title
        self.assetIdLabel.title = viewModel.subtitle
        self.fullText = viewModel.subtitle
        self.balanceLabel.text = viewModel.details

        let locale = LocalizationManager.shared.selectedLocale

        self.assetTitle.text = R.string.localizable.commonAsset(preferredLanguages: locale.rLanguages)
        self.balanceTitle.text = R.string.localizable.commonBalance(preferredLanguages: locale.rLanguages)
    }

}

final class SoraFeeView: BaseFeeView, WalletFormBordering {
    var borderType: BorderType = []

    func bind(viewModel: FeeViewModelProtocol) {
        self.feeLabel.text = viewModel.details
        let locale = LocalizationManager.shared.selectedLocale
        self.feeTitle.text = R.string.localizable.transactionSoranetFeeTitle(preferredLanguages: locale.rLanguages)
    }

    func bind(viewModel: SoraTransactionAmountViewModel) {
        feeLabel.text = viewModel.details
        feeTitle.text = viewModel.title
    }

    @IBOutlet private(set) var feeTitle: UILabel!
    @IBOutlet private(set) var feeLabel: UILabel!

    override func awakeFromNib() {
        self.feeTitle.font = UIFont.styled(for: .paragraph2)
        self.feeLabel.font = UIFont.styled(for: .paragraph2)

        self.feeTitle.text = R.string.localizable.transactionSoranetFeeTitle()
    }

}

final class SoraReceiverView: BaseReceiverView, WalletFormBordering {
    @IBOutlet private(set) var toTitle: UILabel!
    @IBOutlet private(set) var toLabel: GrayCopyButton!
    @IBAction private func buttonTap() {
        if let command = command {
            try? command.execute()
        } else {
            UIPasteboard.general.string = fullText

        }
    }

    private var command: WalletCommandProtocol?

    private var fullText: String?

    var borderType: BorderType = []

    override func awakeFromNib() {
        self.toTitle.font = UIFont.styled(for: .paragraph2)
        self.toTitle.text = R.string.localizable.transactionReceiverTitle()
    }

    func bind(viewModel: MultilineTitleIconViewModelProtocol) {
        self.fullText = viewModel.text
        self.toLabel.title = viewModel.text

        if let model = viewModel as? WalletSoraReceiverViewModel {
            self.command = model.command
            self.toTitle.text = model.title
        }
    }
}

final class EmptyDescriptionInputView: BaseDescriptionInputView {
    var borderType: BorderType {
        get { BorderType.none }
        set { }
    }

    var viewModel: DescriptionInputViewModelProtocol? { nil }

    var selectedFrame: CGRect? { nil }

    func bind(viewModel: DescriptionInputViewModelProtocol) {
        return
    }
}
