import UIKit
import XNetworking
import CommonWallet

// MARK: - View

protocol FriendsViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func setup(with models: [CellViewModel])
    func reloadScreen(with models: [CellViewModel], updatedIndexs: [Int], isExpanding: Bool)
    func startInvitingScreen(with referrer: String)
    func showAlert(with text: String, image: UIImage?)
}

// MARK: - Presenter

protocol FriendsPresenterProtocol: AlertPresentable {
    func setup()
    func didSelectAction(_ action: FriendsPresenter.InvitationActionType)
}

// MARK: - Interactor

protocol FriendsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol FriendsInteractorOutputProtocol: AnyObject {
    func didReceive(rewards: [ReferrerReward],
                    setReferrerFee: Decimal,
                    bondFee: Decimal,
                    unbondFee: Decimal,
                    referralBalance: Decimal,
                    referrer: String)
    func updateReferrer(address: String)
    func updateReferral(balance: Decimal)
    func updateReferral(rewards: [ReferrerReward])
}

// MARK: - Wireframe

protocol FriendsWireframeProtocol: SharingPresentable, AlertPresentable,
                                   ErrorPresentable, HelpPresentable, InputFieldPresentable {
    func showLinkInputViewController(from controller: UIViewController, delegate: InputLinkPresenterOutput)

    func showInputRewardAmountViewController(from controller: UIViewController,
                                             fee: Decimal,
                                             bondedAmount: Decimal,
                                             type: InputRewardAmountType,
                                             delegate: InputRewardAmountPresenterOutput)

    func showActivityViewController(from controller: UIViewController, shareText: String)

    func showReferrerScreen(from controller: UIViewController, referrer: String)
    
    func showActivityDetails(from controller: UIViewController?, model: Transaction, completion: (() -> Void)?)
    func setViewControllers(from controller: UIViewController?, currentController: UIViewController?, referrer: String)
}

// MARK: - Factory

protocol FriendsViewFactoryProtocol: AnyObject {
    static func createView(walletContext: CommonWalletContextProtocol,
                           assetManager: AssetManagerProtocol) -> FriendsViewProtocol?
}
