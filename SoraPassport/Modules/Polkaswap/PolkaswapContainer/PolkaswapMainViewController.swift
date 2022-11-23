import Anchorage
import SoraFoundation
import SoraUI
import UIKit

enum PolkaswapTab: Int {
    case swap = 0
    case pool = 1
}

final class PolkaswapMainViewController: UIViewController & HiddableBarWhenPushed, PolkaswapMainViewProtocol {
    var presenter: PolkaswapMainPresenterProtocol!

    @IBOutlet var logo: UIImageView!
    @IBOutlet var marketButton: NeumorphismButton!
    @IBOutlet var marketTitleLabel: UILabel!
    @IBOutlet var marketTypeLabel: UILabel!
    @IBOutlet var selectorView: SegmentSelectorView!
    @IBOutlet var containerView: UIView!

    var swapView: SwapViewProtocol?
    var poolView: PolkaswapPoolViewProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter.didBecomeActive(true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        presenter.didBecomeActive(false)
    }

    fileprivate func configure() {
        logo.image = R.image.polkaswap()
        marketButton.setImage(R.image.polkaswapSettings(), for: .normal)
        marketButton.addTarget(self, action: #selector(marketPressed), for: .touchUpInside)

        marketTitleLabel.font = UIFont.styled(for: .paragraph1)
        marketTitleLabel.textColor = R.color.neumorphism.textDark()

        marketTypeLabel.font = UIFont.styled(for: .title1).withSize(15.0)
        marketTypeLabel.textColor = R.color.neumorphism.tint()

        selectorView.addTarget(self, action: #selector(updateSelection), for: .valueChanged)

        guard let poolView = poolView else { return }
        containerView.addSubview(poolView.controller.view)
        poolView.controller.view.edgeAnchors == containerView.edgeAnchors

        guard let swapView = swapView else { return }
        swapView.marketLabel = self.marketTypeLabel
        containerView.addSubview(swapView.controller.view!)
        addChild(swapView.controller)
        swapView.controller.view.edgeAnchors == containerView.edgeAnchors

        applyLocalization()
    }

    @objc func updateSelection() {
        let shouldHideMarket = selectorView.selectedSegment != PolkaswapTab.swap.rawValue
        marketButton.isHidden = shouldHideMarket
        marketTypeLabel.isHidden = shouldHideMarket
        marketTitleLabel.isHidden = shouldHideMarket

        if selectorView.selectedSegment == PolkaswapTab.swap.rawValue {
            guard let swapView = swapView else { return }
            containerView.bringSubviewToFront(swapView.controller.view)
            addChild(swapView.controller)
            presenter.didChangeSelectedTab(.swap)
        } else {
            guard let poolView = poolView else { return }
            containerView.bringSubviewToFront(poolView.controller.view)
            addChild(poolView.controller)
            swapView?.controller.resignFirstResponder()
            presenter.didChangeSelectedTab(.pool)
        }
    }

    @objc func marketPressed() {
        swapView?.didPressMarket()
    }
}

extension PolkaswapMainViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    private var locale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    func applyLocalization() {
        navigationItem.title = R.string.localizable
            .tabbarPolkaswapTitle(preferredLanguages: languages)

        marketTitleLabel?.text = R.string.localizable.polkaswapMarket(preferredLanguages: languages).uppercased()

        selectorView?.segments = [R.string.localizable.polkaswapSwapTitle(preferredLanguages: languages),
                                  R.string.localizable.polkaswapPoolTitle(preferredLanguages: languages)]

        swapView?.localizationManager = localizationManager
        poolView?.localizationManager = localizationManager

    }
}
