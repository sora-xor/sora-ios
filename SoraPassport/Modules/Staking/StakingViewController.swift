import UIKit
import Then
import Anchorage
import SoraFoundation

final class StakingViewController: UIViewController {
    var presenter: StakingPresenterProtocol!

    private var comingSoonView: (container: UIView, label: UILabel) = {
        ComingSoonViewFactory.comingSoonView()
    }()

    private var descriptionView: (container: UIView, label: UILabel) = {
        ComingSoonViewFactory.descriptionView()
    }()

    private lazy var linkView: LinkView = {
        LinkView().then {
            $0.addTarget(self, action: #selector(activateLink), for: .touchUpInside)
        }
    }()

    private var viewModel: ComingSoonViewModel! {
        didSet {
            reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()

        presenter.setup(preferredLocalizations: languages)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        navigationController?.navigationBar.shadowIsHidden = true
    }

    private func configure() {

        let scrollView = UIScrollView().then {
            view.addSubview($0)
            $0.edgeAnchors == view.safeAreaLayoutGuide.edgeAnchors
        }

        let container = UIView().then {
            scrollView.addSubview($0)
            $0.edgeAnchors == scrollView.edgeAnchors
            $0.widthAnchor == scrollView.widthAnchor
        }

        createStackView().do {
            container.addSubview($0)
            $0.edgeAnchors.verticalAnchors == container.edgeAnchors.verticalAnchors + 24
            $0.edgeAnchors.horizontalAnchors == container.edgeAnchors.horizontalAnchors + 16
        }
    }

    private func createStackView() -> UIView {

        let stackView = UIStackView(arrangedSubviews: [
            comingSoonView.container,
            descriptionView.container,
            UIView.empty(height: 24),
            linkView
        ]).then {
            $0.axis = .vertical
            $0.spacing = 0
        }

        return stackView
    }

    private func reloadData() {
        comingSoonView.label.do {
            $0.attributedText = viewModel.comingSoonText
                .styled(.uppercase3)
        }

        descriptionView.label.do {
            $0.attributedText = viewModel.comingSoonDescriptionText
                .styled(.paragraph1)
        }

        linkView.do {
            $0.iconImage = viewModel.linkViewModel?.image
            $0.titleAttributedText = viewModel.linkViewModel?.title
            $0.linkTitleAttributedText = viewModel.linkViewModel?.linkTitle
        }
    }

    @objc private func activateLink() {
        presenter.openLink(url: viewModel.linkViewModel?.link)
    }
}

extension StakingViewController: StakingViewProtocol {
    func didReceive(viewModel: ComingSoonViewModel) {
        self.viewModel = viewModel
    }
}

extension StakingViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        navigationItem.title = R.string.localizable
            .tabbarStakingTitle(preferredLanguages: languages)

        presenter?.setup(preferredLocalizations: languages)
    }
}
