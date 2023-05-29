import UIKit
import SoraUIKit
import SoraFoundation

final class MainTabBarViewController: UITabBarController {
	var presenter: MainTabBarPresenterProtocol!
    var middleButtonHadler: (() -> Void)?
    private var viewAppeared: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        self.delegate = self

        let tabBar = TabBar(frame: tabBar.frame)
        tabBar.middleButton.sora.image = R.image.wallet.polkaswap()
        tabBar.middleButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.middleButtonHadler?()
        }
        tabBar.coverButton.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.middleButtonHadler?()
        }
        tabBar.middleButtonTitleLabel.sora.text = R.string.localizable.polkaswapSwapTitle(preferredLanguages: .currentLocale)
        setValue(tabBar, forKey: "tabBar")
        
        configureTabBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !viewAppeared {
            viewAppeared = true
            presenter.setup()
        }
    }

    private func configureTabBar() {
        tabBar.tintColor = R.color.neumorphism.tint()

        if #available(iOS 13.0, *) {
            let appearance = UITabBarAppearance()

            appearance.backgroundImage = UIImage.background(from: R.color.neumorphism.base()!)
            appearance.shadowImage = UIImage.background(from: R.color.neumorphism.separator()!)

            let normalAttributes = [NSAttributedString.Key.foregroundColor: R.color.neumorphism.brown()!,
                                    NSAttributedString.Key.font: FontType.textBoldXS.font]
            let selectedAttributes = [NSAttributedString.Key.foregroundColor: R.color.neumorphism.tint()!,
                                      NSAttributedString.Key.font: FontType.textBoldXS.font]

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

extension MainTabBarViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
    
    func applyLocalization() {
        let languages = localizationManager?.preferredLocalizations
        (tabBar as? TabBar)?.middleButtonTitleLabel.sora.text = R.string.localizable.polkaswapSwapTitle(preferredLanguages: languages)
    }
}
