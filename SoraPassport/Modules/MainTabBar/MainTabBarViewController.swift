import UIKit

final class MainTabBarViewController: UITabBarController {
	var presenter: MainTabBarPresenterProtocol!

    private var viewAppeared: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        self.delegate = self

        configureTabBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !viewAppeared {
            viewAppeared = true
            presenter.setup()
        }

        presenter.viewDidAppear()
    }

    private func configureTabBar() {
        tabBar.tintColor = R.color.neumorphism.tint()

        if #available(iOS 13.0, *) {
            let appearance = UITabBarAppearance()

            appearance.backgroundImage = UIImage.background(from: R.color.neumorphism.base()!)
            appearance.shadowImage = UIImage.background(from: R.color.neumorphism.separator()!)

            let normalAttributes = [NSAttributedString.Key.foregroundColor: R.color.baseContentTertiary()!]
            let selectedAttributes = [NSAttributedString.Key.foregroundColor: R.color.neumorphism.tint()!]

            appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes

            tabBar.standardAppearance = appearance

            // fix transparent background on iOS 15+
            if #available(iOS 15.0, *) {
                tabBar.setValue(tabBar.standardAppearance, forKey: "scrollEdgeAppearance")
                //TODO: change this to more apropriate API
                //tabBar.scrollEdgeAppearance = tabBar.standardAppearance
            }
        } else {
            tabBar.backgroundImage = UIImage.background(from: R.color.neumorphism.base()!)
            tabBar.shadowImage = UIImage.background(from: R.color.neumorphism.separator()!)
        }
    }
}

extension MainTabBarViewController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController,
                          shouldSelect viewController: UIViewController) -> Bool {
        if let scrollableController = viewController as? ScrollsToTop {
            scrollableController.scrollToTop()
        }

        return true
    }
}

extension MainTabBarViewController: MainTabBarViewProtocol {
    func didReplaceView(for newView: UIViewController, for index: Int) {
        guard var newViewControllers = viewControllers else {
            return
        }

        newViewControllers[index] = newView

        self.setViewControllers(newViewControllers, animated: false)
    }
}
