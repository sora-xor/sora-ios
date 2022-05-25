import UIKit
import CommonWallet

protocol MainTabBarViewProtocol: ControllerBackedProtocol {
    func didReplaceView(for newView: UIViewController, for index: Int)
}

protocol MainTabBarPresenterProtocol: class {
    func setup()
    func viewDidAppear()
}

protocol MainTabBarInteractorInputProtocol: class {
    func setup()
//    func configureNotifications()
//    func configureDeepLink()
//
//    func searchPendingDeepLink()
//    func resolvePendingDeepLink()
}

protocol MainTabBarInteractorOutputProtocol: class {
//    func didReceive(deepLink: DeepLinkProtocol)
    func didReloadSelectedAccount()
    func didReloadSelectedNetwork()
    func didUpdateWalletInfo()
    func didRequestImportAccount()
    func didRequestMigration(with service: MigrationServiceProtocol)
    func didEndMigration()
    func didEndTransaction()
}

protocol MainTabBarWireframeProtocol: AlertPresentable, AuthorizationAccessible {
    var walletContext: CommonWalletContextProtocol { get set }

    func showNewWalletView(on view: MainTabBarViewProtocol?)
    func reloadWalletContent()

    func presentAccountImport(on view: MainTabBarViewProtocol?)
    func presentClaim(on view: MainTabBarViewProtocol?, with service: MigrationServiceProtocol)
    func removeClaim(on view: MainTabBarViewProtocol?)
    
    func showTransactionSuccess(on view: MainTabBarViewProtocol?)
}

protocol MainTabBarViewFactoryProtocol: class {
    static func createView() -> MainTabBarViewProtocol?
    static func reloadWalletView(on view: MainTabBarViewProtocol,
                                 wireframe: MainTabBarWireframeProtocol)
}
