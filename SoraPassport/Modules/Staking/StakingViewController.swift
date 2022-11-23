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

    private var promoView: ComingSoonView?

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

        let container = UIView().then {
            view.addSubview($0)
            $0.topAnchor == view.safeAreaLayoutGuide.topAnchor
            $0.leadingAnchor == view.safeAreaLayoutGuide.leadingAnchor
            $0.trailingAnchor == view.safeAreaLayoutGuide.trailingAnchor
            $0.bottomAnchor == view.safeAreaLayoutGuide.bottomAnchor
        }

        guard let soon = UINib(resource: R.nib.comingSoonView).instantiate(withOwner: nil).first as? ComingSoonView else {
            return
        }
        container.addSubview(soon)
        soon.edgeAnchors.verticalAnchors == container.edgeAnchors.verticalAnchors
        soon.edgeAnchors.horizontalAnchors == container.edgeAnchors.horizontalAnchors
        promoView = soon
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

        promoView?.titleText = viewModel.comingSoonText
        promoView?.text = viewModel.comingSoonDescriptionText
        promoView?.image = viewModel.image
        promoView?.linkTitle = self.viewModel.linkViewModel?.title ?? ""
        promoView?.tapClosure = {
            self.presenter.openLink(url: self.viewModel.linkViewModel?.link)
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
