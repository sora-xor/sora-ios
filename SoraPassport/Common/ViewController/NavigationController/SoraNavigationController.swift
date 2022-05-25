import UIKit

protocol HiddableBarWhenPushed: class {}

final class SoraNavigationController: UINavigationController, UINavigationControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
    }

    override var childForStatusBarStyle: UIViewController? {
        return self.topViewController
    }

    private func setup() {
        delegate = self
    }

    // MARK: UINavigationControllerDelegate

    public func navigationController(_ navigationController: UINavigationController,
                                     willShow viewController: UIViewController, animated: Bool) {
        updateNavigationBarState(in: viewController)
        setupBackButtonItem(for: viewController)
    }

    private func updateNavigationBarState(in viewController: UIViewController) {
        let isHidden = viewController as? HiddableBarWhenPushed != nil
        setNavigationBarHidden(isHidden, animated: true)
    }

    private func setupBackButtonItem(for viewController: UIViewController) {
        let backButtonItem = viewController.navigationItem.backBarButtonItem ?? UIBarButtonItem()
        backButtonItem.title = " "
        viewController.navigationItem.backBarButtonItem = backButtonItem
    }
}

extension SoraNavigationController: ScrollsToTop {
    func scrollToTop() {
        if let scrollableController = topViewController as? ScrollsToTop {
            scrollableController.scrollToTop()
        }
    }
}
