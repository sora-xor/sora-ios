import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

final class ReceiveViewFactory: ReceiveViewFactoryProtocol {
    let account: AccountItem
    let chain: Chain
    let localizationManager: LocalizationManagerProtocol

    weak var commandFactory: WalletCommandFactoryProtocol?

    private lazy var iconGenerator = PolkadotIconGenerator()

    init(account: AccountItem, chain: Chain, localizationManager: LocalizationManagerProtocol) {
        self.account = account
        self.chain = chain
        self.localizationManager = localizationManager
    }

    func createHeaderView() -> UIView? {
        let icon = try? iconGenerator.generateFromAddress(account.address)
            .imageWithFillColor(R.color.baseBackground()!,
                                size: CGSize(width: 32.0, height: 32.0),
                                contentScale: UIScreen.main.scale)

        let receiveView: ReceiveHeaderView = R.nib.receiveHeaderView(owner: nil)!
        if account.username.isEmpty {
            receiveView.accountView.title = account.address
            receiveView.accountView.subtitle = ""
            receiveView.accountView.layout = .singleTitle
        } else {
            receiveView.accountView.title = account.username
            receiveView.accountView.subtitle = account.address
            receiveView.accountView.layout = .largeIconTitleSubtitle
        }

        receiveView.accountView.iconImage = icon
        receiveView.accountView.subtitleLabel?.lineBreakMode = .byTruncatingMiddle
        receiveView.accountView.titleLabel?.lineBreakMode = .byTruncatingMiddle
        receiveView.accountView.titleLabel?.font = UIFont.styled(for: .title1).withSize(15)
        receiveView.accountView.subtitleLabel?.font = UIFont.styled(for: .paragraph3)

        let locale = localizationManager.selectedLocale

        let command = SendToContactCommand(nextAction: {
            UIPasteboard.general.string = self.account.address
            let success = ModalAlertFactory.createSuccessAlert(R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages)) 
            try? self.commandFactory?.preparePresentationCommand(for: success).execute()
        })
        receiveView.actionCommand = command

        return receiveView
    }
}
