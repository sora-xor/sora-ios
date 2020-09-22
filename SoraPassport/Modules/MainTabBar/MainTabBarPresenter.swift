import Foundation

final class MainTabBarPresenter {
	weak var view: MainTabBarViewProtocol?
	var interactor: MainTabBarInteractorInputProtocol!
	var wireframe: MainTabBarWireframeProtocol!

    var logger: LoggerProtocol?

    private var shouldRequestNotificationConfiguration: Bool = true
    private var shouldRequestDeepLinkConfiguration: Bool = true

    let children: [ChildPresenterProtocol]

    init(children: [ChildPresenterProtocol]) {
        self.children = children
    }
}

extension MainTabBarPresenter: MainTabBarPresenterProtocol {
    func setup() {
        children.forEach { $0.setup() }

        if shouldRequestNotificationConfiguration {
            shouldRequestNotificationConfiguration = false
            interactor.configureNotifications()
        }
    }

    func viewDidAppear() {
        if shouldRequestDeepLinkConfiguration {
            shouldRequestDeepLinkConfiguration = false
            interactor.configureDeepLink()
        }

        interactor.searchPendingDeepLink()
    }
}

extension MainTabBarPresenter: MainTabBarInteractorOutputProtocol {
    func didReceive(deepLink: DeepLinkProtocol) {
        for child in children {
            if let navigator = child as? DeepLinkNavigatorProtocol, deepLink.accept(navigator: navigator) {
                interactor.resolvePendingDeepLink()
                return
            }
        }
    }
}
