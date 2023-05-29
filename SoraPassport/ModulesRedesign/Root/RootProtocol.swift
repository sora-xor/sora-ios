import UIKit

protocol RootPresenterProtocol: AnyObject {
    func loadOnLaunch()
}

protocol RootWireframeProtocol: AnyObject {
    func showLocalAuthentication(on view: UIWindow)
    func showOnboarding(on view: UIWindow)
    func showBroken(on view: UIWindow)
    func showPincodeSetup(on view: UIWindow)
}

protocol RootInteractorInputProtocol: AnyObject {
    func setup()
    func decideModuleSynchroniously()
}

protocol RootInteractorOutputProtocol: AnyObject {
    func didDecideOnboarding()
    func didDecideLocalAuthentication()
    func didDecideBroken()
    func didDecidePincodeSetup()
}

protocol RootPresenterFactoryProtocol: AnyObject {
    static func createPresenter(with view: SoraWindow) -> RootPresenterProtocol
}
