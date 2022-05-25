import CommonWallet
import SoraFoundation
import SoraUI
import Foundation
import UIKit


final class InvisibleHeaderView: BaseOperationDefinitionHeaderView {
    func bind(viewModel: MultilineTitleIconViewModelProtocol) {

    }
}

final class SoraAssetView: BaseSelectedAssetView, WalletFormBordering {

    @IBOutlet private(set) var assetLabel: UILabel!
    @IBOutlet private(set) var assetNameLabel: UILabel!
    @IBOutlet private(set) var assetIcon: UIImageView!
    private var fullText: String?

    @IBOutlet private(set) var balanceTitle: UILabel!
    @IBOutlet private(set) var balanceLabel: UILabel!

    weak var delegate: SelectedAssetViewDelegate?

    var activated: Bool = false

    var borderType: BorderType = .bottom

    override func awakeFromNib() {
        self.assetLabel.font = UIFont.styled(for: .display1)
        self.balanceTitle.font = UIFont.styled(for: .title1).withSize(15)
        self.balanceLabel.font = UIFont.styled(for: .paragraph1, isBold: true).withSize(18)
    }

    func viewDidLayoutSubviews() {
        super.inputViewController?.viewDidLayoutSubviews()
    }

    func bind(viewModel: AssetSelectionViewModelProtocol) {
        if let concreteViewModel = viewModel as? WalletTokenViewModel,
           let iconViewModel = concreteViewModel.iconViewModel {
            iconViewModel.loadImage { [weak self] (icon, _) in
                self?.assetIcon.image = icon
            }
            self.assetNameLabel.text = concreteViewModel.header
        } else {
            self.assetIcon.image = viewModel.icon
        }
        self.assetLabel.text = viewModel.title

        self.fullText = viewModel.subtitle
        let amount = viewModel.details

        let locale = LocalizationManager.shared.selectedLocale
        self.balanceLabel.attributedText = amount.prettyCurrency(baseFont: balanceLabel.font, locale: locale)
        self.balanceTitle.text = R.string.localizable.commonBalance(preferredLanguages: locale.rLanguages)
    }

}

final class SoraFeeView: BaseFeeView, WalletFormBordering {
    var borderType: BorderType = []

    func bind(viewModel: FeeViewModelProtocol) {
        let locale = LocalizationManager.shared.selectedLocale
        if titleLabel == nil {
            let text = R.string.localizable.transactionSoranetFeeTitle(preferredLanguages: locale.rLanguages) + ": " + viewModel.details
            let decor = text.decoratedWith([.font: UIFont.styled(for: .paragraph2)], adding: [.font: UIFont.styled(for: .paragraph2, isBold:true)], to: [viewModel.details])
            feeLabel.attributedText = decor
        } else {
            feeLabel.text = viewModel.details
            titleLabel?.text = viewModel.title
        }
    }

    func bind(viewModel: SoraTransactionAmountViewModel) {
        if titleLabel == nil {
            feeLabel.text = viewModel.title + ": " + viewModel.details
        } else {
            feeLabel.text = viewModel.details
            titleLabel?.text = viewModel.title
        }
    }

    @IBOutlet private(set) var feeLabel: UILabel!
    @IBOutlet private(set) var titleLabel: UILabel?

    override func awakeFromNib() {
        feeLabel.font = UIFont.styled(for: .paragraph2, isBold: true)
        titleLabel?.font = UIFont.styled(for: .title1).withSize(15)
        titleLabel?.text = R.string.localizable.transactionSoranetFeeTitle()
    }
}

final class SoraReceiverView: BaseReceiverView, WalletFormBordering {
    @IBOutlet private(set) var toTitle: UILabel!
    @IBOutlet private(set) var toLabel: UILabel!
    @IBOutlet private(set) var copyImage: UIImageView!
    @IBOutlet private(set) var copyButton: UIButton!
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
        let locale = LocalizationManager.shared.selectedLocale
        toTitle.font = UIFont.styled(for: .title1).withSize(15)
        toTitle.text = R.string.localizable.commonRecipient(preferredLanguages: locale.rLanguages)

        copyImage.image = R.image.copyNeu()
        copyButton.setTitle("", for: .normal)
    }

    func bind(viewModel: MultilineTitleIconViewModelProtocol) {
        self.fullText = viewModel.text
        self.toLabel.text = viewModel.text

        if let model = viewModel as? WalletSoraReceiverViewModel {
            self.command = model.command
            self.toTitle.text = model.title
        }
    }
}

final class SoraDetailsCopyView: BaseReceiverView, WalletFormBordering {
    @IBOutlet private(set) var toTitle: UILabel!
    @IBOutlet private(set) var copyButton: GrayCopyButton!
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
        let locale = LocalizationManager.shared.selectedLocale
        toTitle.font = UIFont.styled(for: .title1).withSize(15)
        toTitle.text = R.string.localizable.commonRecipient(preferredLanguages: locale.rLanguages)
    }

    func bind(viewModel: MultilineTitleIconViewModelProtocol) {
        self.fullText = viewModel.text
        self.copyButton.title = viewModel.text

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
