import UIKit
import SoraUI
import Then
import Anchorage
import SoraFoundation

final class ParliamentViewController: UIViewController {

    var presenter: ParliamentPresenterProtocol!

    private var comingSoonView: (container: UIView, label: UILabel) = {
        ComingSoonViewFactory.comingSoonView()
    }()

    private var descriptionView: (container: UIView, label: UILabel) = {
        ComingSoonViewFactory.descriptionView()
    }()

    private lazy var buttonRoundedView: RoundedNavigationButton! = {
        RoundedNavigationButton().then {
            $0.addTarget(self, action: #selector(activateReferenda), for: .touchUpInside)
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

        // TODO: SN-257. return after update build sysytem to Xcode 12
//        if #available(iOS 14.0, *) {
//            navigationItem.backButtonDisplayMode = .minimal
//            navigationItem.backButtonTitle = R.string.localizable
//                .tabbarParliamentTitle(preferredLanguages: languages)
//        } else {
//        }
        navigationItem.backBarButtonItem = UIBarButtonItem(
            title: "", style: .plain, target: nil, action: nil
        )

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
        
        promoView?.titleText = viewModel.comingSoonText
        promoView?.text = viewModel.comingSoonDescriptionText
        promoView?.image = viewModel.image
        promoView?.linkTitle = self.viewModel.linkViewModel?.title ?? ""
        promoView?.tapClosure = {
            self.presenter.openLink(url: self.viewModel.linkViewModel?.link)
        }
    }

    @objc private func activateReferenda() {
        presenter.activateReferenda()
    }
}

extension ParliamentViewController: ParliamentViewProtocol {
    func didReceive(viewModel: ComingSoonViewModel) {
        self.viewModel = viewModel
    }
}

extension ParliamentViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        navigationItem.title = R.string.localizable
            .tabbarParliamentTitle(preferredLanguages: languages)

        presenter?.setup(preferredLocalizations: languages)
    }
}
