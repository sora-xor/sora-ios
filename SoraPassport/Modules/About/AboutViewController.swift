import UIKit
import Then
import Anchorage
import SoraFoundation

final class AboutViewController: UIViewController {

    var presenter: AboutPresenterProtocol!

    private lazy var scrollView: UIScrollView = {
        UIScrollView().then {
            view.addSubview($0)
            $0.edgeAnchors == view.safeAreaLayoutGuide.edgeAnchors
        }
    }()

    private lazy var containerView: UIView = {
        UIView().then {
            scrollView.addSubview($0)
            $0.edgeAnchors == scrollView.edgeAnchors
            $0.widthAnchor == scrollView.widthAnchor
        }
    }()

    private lazy var linkViewButtons: [LinkView] = {
        optionViewModels.enumerated().map { (index, option) in
            LinkView(separatorIsVisible: true).then {
                $0.tag = index
                $0.iconImage = option.image
                $0.titleAttributedText = option.title
                $0.linkTitleAttributedText = option.subtitle
                $0.iconTintColor = R.color.baseContentQuaternary()
                $0.backgroundColor = R.color.baseBackground()
                $0.addTarget(
                    self, action: #selector(linkViewAction(_:)),
                    for: .touchUpInside
                )
            }
        }
    }()

    private(set) var optionViewModels: [AboutOptionViewModelProtocol] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        configure()
    }
}

private extension AboutViewController {

    func configure() {
        navigationItem.title = R.string.localizable.aboutTitle(preferredLanguages: languages)
        view.backgroundColor = R.color.baseBackground()
        let stackView = UIStackView(
            arrangedSubviews: linkViewButtons
        ).then {
            $0.axis = .vertical
            $0.spacing = 0
        }

        stackView.do {
            containerView.addSubview($0)
            $0.edgeAnchors.verticalAnchors == containerView.edgeAnchors.verticalAnchors + 24
            $0.edgeAnchors.horizontalAnchors == containerView.edgeAnchors.horizontalAnchors + 16
        }
    }

    @objc private func linkViewAction(_ sender: LinkView) {
        let model = optionViewModels[sender.tag]
        presenter.activateOption(model.option)
    }
}

extension AboutViewController: AboutViewProtocol {
    func didReceive(optionViewModels: [AboutOptionViewModelProtocol]) {
        self.optionViewModels = optionViewModels
    }
}

extension AboutViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {

    }
}
