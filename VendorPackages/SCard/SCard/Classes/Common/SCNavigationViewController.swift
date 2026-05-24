final class SCNavigationViewController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
    }

    override var childForStatusBarStyle: UIViewController? {
        return self.topViewController
    }

    private func setupBackButtonItem(for viewController: UIViewController) {
        let backButtonItem = viewController.navigationItem.backBarButtonItem ?? UIBarButtonItem()
        backButtonItem.title = " "
        viewController.navigationItem.backBarButtonItem = backButtonItem
    }
}

extension SCNavigationViewController: UINavigationControllerDelegate {

    public func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController, animated: Bool
    ) {
        setupBackButtonItem(for: viewController)
    }
}
