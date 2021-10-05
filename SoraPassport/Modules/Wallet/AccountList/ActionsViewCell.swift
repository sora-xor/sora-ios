import UIKit
import SoraUI
import CommonWallet

class ActionsViewCell: UICollectionViewCell {

    private(set) var actionsViewModel: ActionsViewModelProtocol?

    @IBOutlet weak var buttonSend: RoundedButton!
    @IBOutlet weak var buttonReceive: RoundedButton!

    @IBAction private func actionSend() {
        if let actionsViewModel = actionsViewModel {
            try? actionsViewModel.send.command.execute()
        }
    }

    @IBAction private func actionReceive() {
        if let actionsViewModel = actionsViewModel {
            try? actionsViewModel.receive.command.execute()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        buttonSend.roundedBackgroundView?.shadowColor = shadow.color
        buttonSend.roundedBackgroundView?.shadowOpacity = shadow.opacity
        buttonSend.roundedBackgroundView?.shadowOffset = shadow.offset
        buttonSend.roundedBackgroundView?.shadowRadius = shadow.blurRadius
        buttonSend.roundedBackgroundView?.shadowColor = shadow.color
        buttonSend.roundedBackgroundView?.cornerRadius = 10
        buttonSend.imageWithTitleView?.titleFont = UIFont.styled(for: .paragraph2)

        buttonReceive.roundedBackgroundView?.shadowColor = shadow.color
        buttonReceive.roundedBackgroundView?.shadowOpacity = shadow.opacity
        buttonReceive.roundedBackgroundView?.shadowOffset = shadow.offset
        buttonReceive.roundedBackgroundView?.shadowRadius = shadow.blurRadius
        buttonReceive.roundedBackgroundView?.shadowColor = shadow.color
        buttonReceive.roundedBackgroundView?.cornerRadius = 10
        buttonReceive.imageWithTitleView?.titleFont = UIFont.styled(for: .paragraph2)
    }

    lazy var shadow = WalletShadowStyle(offset: CGSize(width: 0.0, height: 1.0),
                                   color: UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.35),
                                   opacity: 1.0,
                                   blurRadius: 4.0)
}

extension ActionsViewCell: WalletViewProtocol {

    var viewModel: WalletViewModelProtocol? {
        return actionsViewModel
    }

    func bind(viewModel: WalletViewModelProtocol) {
        guard let actionsViewModel = viewModel as? ActionsViewModelProtocol else {
            return
        }

        self.actionsViewModel = actionsViewModel
        buttonSend.imageWithTitleView?.title = actionsViewModel.send.title
        buttonReceive.imageWithTitleView?.title = actionsViewModel.receive.title

        setNeedsLayout()
    }
}
