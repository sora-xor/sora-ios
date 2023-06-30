import Foundation
import SoraKeystore
import SoraFoundation
import CommonWallet
import SoraUIKit
import RobinHood
import SCard

final class MoreMenuWireframe: MoreMenuWireframeProtocol, AuthorizationPresentable, CustomPresentable {

    private(set) var settingsManager: SettingsManagerProtocol
    private(set) var localizationManager: LocalizationManagerProtocol
    private(set) var walletContext: CommonWalletContextProtocol

    private let address: AccountAddress
    private let fiatService: FiatServiceProtocol
    private let balanceFactory: BalanceProviderFactory
    private var assetsProvider: AssetProviderProtocol

    init(settingsManager: SettingsManagerProtocol,
         localizationManager: LocalizationManagerProtocol,
         walletContext: CommonWalletContextProtocol,
         fiatService: FiatServiceProtocol,
         balanceFactory: BalanceProviderFactory,
         address: AccountAddress,
         assetsProvider: AssetProviderProtocol
    ) {
        self.settingsManager = settingsManager
        self.localizationManager = localizationManager
        self.walletContext = walletContext
        self.address = address
        self.fiatService = fiatService
        self.balanceFactory = balanceFactory
        self.assetsProvider = assetsProvider
    }
        
    func showChangeAccountView(from view: MoreMenuViewProtocol?) {
        guard let changeAccountView = ChangeAccountViewFactory.changeAccountViewController(with: {}) else {
            return
        }
        
        guard let presentingVC = view?.controller else {
            return
        }
        
        present(blurred: changeAccountView.controller, on: presentingVC)
    }
    
    func showSoraCard(from view: MoreMenuViewProtocol?) {
        guard let view = view else { return }
        SCard.shared?.start(in: view.controller)
    }
    
    func showInformation(from view: MoreMenuViewProtocol?) {
        let informationView = SettingsInformationFactory.createInformation()
        
        guard let presentingVC = view?.controller else {
            return
        }
        
        present(blurred: informationView.controller, on: presentingVC)
    }
    
    func showNodes(from view: MoreMenuViewProtocol?) {
        guard let nodesView = NodesViewFactory.createView() else {
            return
        }
        if let navigationController = view?.controller.navigationController {
            nodesView.controller.hidesBottomBarWhenPushed = true

            let containerView = BlurViewController()
            containerView.modalPresentationStyle = .overFullScreen

            let newNav = SoraNavigationController(rootViewController: nodesView.controller)
            newNav.navigationBar.backgroundColor = .clear
            newNav.addCustomTransitioning()
            containerView.add(newNav)
            navigationController.present(containerView, animated: true)
        }
    }

    func showPersonalDetailsView(from view: MoreMenuViewProtocol?, completion: @escaping () -> Void) {
    }

    func showFriendsView(from view: MoreMenuViewProtocol?) {
        guard let friendsView = FriendsViewFactory.createTestView(walletContext: walletContext) else {
            return
        }
        if let navigationController = view?.controller.navigationController {
            let containerView = BlurViewController()
            containerView.modalPresentationStyle = .overFullScreen

            let newNav = SoraNavigationController(rootViewController: friendsView.controller)
            newNav.navigationBar.backgroundColor = .clear
            newNav.addCustomTransitioning()
            containerView.add(newNav)
            navigationController.present(containerView, animated: true)
        }
    }

    func showAppSettings(from view: MoreMenuViewProtocol?) {
        let settingsView = AppSettingsFactory.createAppSettings()
        
        guard let presentingVC = view?.controller else {
            return
        }
        
        present(blurred: settingsView.controller, on: presentingVC)
    }
    
    func showSecurity(from view: MoreMenuViewProtocol?) {
        let securityView = ProfileLoginFactory.createView()
        
        guard let presentingVC = view?.controller else {
            return
        }
        
        present(blurred: securityView.controller, on: presentingVC)
    }
}
