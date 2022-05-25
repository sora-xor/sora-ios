import UIKit
import Then
import SoraUI
import Anchorage
import SoraFoundation

final class FriendsViewController: UIViewController {
    var presenter: FriendsPresenterProtocol!

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var button: NeumorphismButton!

    // MARK: - Controls

    private lazy var containerView: UIView = {
        UIView().then {
            view.addSubview($0)
            $0.topAnchor == view.topAnchor
            $0.edgeAnchors.horizontalAnchors == view.safeAreaLayoutGuide.horizontalAnchors
        }
    }()

    private lazy var descriptionLabel: UILabel = {
        UILabel().then {
            $0.numberOfLines = 0
            $0.font = UIFont.styled(for: .paragraph1)
            $0.textColor = R.color.baseContentTertiary()
        }
    }()

    private lazy var logo: UIImageView = {
        UIImageView().then {
            $0.image = R.image.pin.soraVertical()!
            $0.contentMode = .scaleAspectFit
        }
    }()

    private lazy var inviteCodeTitleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .uppercase2, isBold: true)
            $0.textColor = R.color.baseContentPrimary()
        }
    }()

    private lazy var inviteCodeValueLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .paragraph1)
            $0.textColor = R.color.baseContentPrimary()
        }
    }()

    private lazy var inviteCodeCopyButton: SoraButton = {
        SoraButton().then {
            $0.widthAnchor == 32
            $0.heightAnchor == 32
            $0.changesContentOpacityWhenHighlighted = true
            $0.imageWithTitleView?.iconImage = R.image.copy()
            $0.roundedBackgroundView?.cornerRadius = 16
            $0.roundedBackgroundView?.shadowOpacity = 0
            $0.roundedBackgroundView?.shadowColor = .clear
            $0.roundedBackgroundView?.fillColor = R.color.baseBackground()!
            $0.roundedBackgroundView?.highlightedFillColor = R.color.baseBackgroundHover()!
            $0.addTarget(self, action: #selector(copyAction), for: .touchUpInside)
        }
    }()

    private lazy var rewardsViewController: RewardsViewController = {
        RewardsViewController().then {
            $0.localizationManager = localizationManager
            $0.superview = self
            _ = $0.view
        }
    }()

    private lazy var bottomContainerView: UIView = {
        UIView().then {
            $0.backgroundColor = R.color.baseBackground()
        }
    }()

    private lazy var shareInviteButton: SoraButton = {
        SoraButton().then {
            $0.heightAnchor == 48
            $0.tintColor = R.color.brandWhite()
            $0.roundedBackgroundView?.fillColor = R.color.themeAccent()!
            $0.roundedBackgroundView?.highlightedFillColor = R.color.themeAccentPressed()!
            $0.roundedBackgroundView?.cornerRadius = 12
            $0.roundedBackgroundView?.shadowOpacity = 0
            $0.roundedBackgroundView?.shadowColor = .clear
            $0.changesContentOpacityWhenHighlighted = true
            $0.imageWithTitleView?.title = shareInviteTitle
            $0.imageWithTitleView?.iconImage = R.image.shareArrow()
            $0.imageWithTitleView?.titleColor = R.color.brandWhite()
            $0.imageWithTitleView?.titleFont = UIFont.styled(for: .button, isBold: true)
            $0.imageWithTitleView?.spacingBetweenLabelAndIcon = 8
            $0.imageWithTitleView?.displacementBetweenLabelAndIcon = 1
            $0.addTarget(self, action: #selector(shareInviteAction), for: .touchUpInside)
        }
    }()

    private lazy var applyInviteButton: SoraButton = {
        SoraButton().then {
            $0.heightAnchor == 48
            $0.tintColor = R.color.baseContentPrimary()
            $0.roundedBackgroundView?.fillColor = R.color.baseBackground()!
            $0.roundedBackgroundView?.highlightedFillColor = R.color.baseBackgroundHover()!
            $0.roundedBackgroundView?.cornerRadius = 12
            $0.roundedBackgroundView?.shadowOpacity = 0
            $0.roundedBackgroundView?.shadowColor = .clear
            $0.changesContentOpacityWhenHighlighted = true
            $0.imageWithTitleView?.title = applyInviteTitle
            $0.imageWithTitleView?.titleColor = R.color.baseContentPrimary()
            $0.imageWithTitleView?.titleFont = UIFont.styled(for: .paragraph1, isBold: true)
            $0.imageWithTitleView?.displacementBetweenLabelAndIcon = 1
            $0.addTarget(self, action: #selector(applyInviteAction), for: .touchUpInside)
        }
    }()

    // MARK: - Vars

    /// Used to correction the distance to the top of the screen
    private var statusBarHeightCorrection: CGFloat {
        UIApplication.shared.statusBarFrame.size.height + 10
    }

    /// Used to correction the middle position of the pull-up controller
    /// and prevent moving content of the main view on animation to the upper state
    private var navigationBarHeightCorrection: CGFloat {
        statusBarHeightCorrection +
            (navigationController?.navigationBar.frame.size.height ?? 0)
    }

    private var friendsViewModel: FriendsInvitationViewModelProtocol? {
        didSet {
            if let viewModel = friendsViewModel {
                applyInviteButton.isHidden = !viewModel.canAcceptInvitation
                inviteCodeValueLabel.attributedText = viewModel.invitationCode
                    .uppercased().styled(.paragraph1)
            } else {
                applyInviteButton.isHidden = true
                inviteCodeTitleLabel.isHidden = true
                inviteCodeValueLabel.isHidden = true
                inviteCodeCopyButton.isHidden = true
            }
        }
    }

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        setupLocalization()
//        configure()
        configureNew()

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.viewDidAppear()
    }
}

// MARK: - Private Functions

private extension FriendsViewController {

    func configureNew() {
        label.font = UIFont.styled(for: .paragraph2)
        label.textColor = R.color.neumorphism.textDark()
        button.addTarget(self, action: #selector(shareInviteAction), for: .touchUpInside)
    }

    func configure() {
        navigationItem.title = R.string.localizable.tabbarFriendsTitle(preferredLanguages: languages)
        view.backgroundColor = R.color.baseBackground()
        // top info
        createStackView().do {
            containerView.addSubview($0)
            $0.edgeAnchors.verticalAnchors == containerView.edgeAnchors.verticalAnchors + 16
            $0.edgeAnchors.horizontalAnchors == containerView.edgeAnchors.horizontalAnchors + 16
        }

        bottomContainerView.do {
            view.addSubview($0)
            $0.bottomAnchor == view.bottomAnchor
            $0.leadingAnchor == view.leadingAnchor
            $0.trailingAnchor == view.trailingAnchor
        }

        // buttons panel
        let buttonStackView = UIStackView(arrangedSubviews: [
            shareInviteButton
        ]).then {
            $0.axis = .vertical
            $0.spacing = 8
        }

        bottomContainerView.addSubview(buttonStackView)
        let insets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        buttonStackView.edgeAnchors == bottomContainerView.safeAreaLayoutGuide.edgeAnchors + insets

        // separator
        let separator = UIView().then {
            $0.backgroundColor = R.color.baseBorderPrimary()
            $0.heightAnchor == 0.5
        }

        bottomContainerView.addSubview(separator)
        separator.topAnchor == bottomContainerView.topAnchor
        separator.leadingAnchor == bottomContainerView.leadingAnchor
        separator.trailingAnchor == bottomContainerView.trailingAnchor
    }

    func createStackView() -> UIView {
        UIStackView(arrangedSubviews: [
            descriptionLabel,
            logo
        ]).then {
            $0.axis = .vertical
            $0.spacing = 80
            logo.widthAnchor == $0.widthAnchor
            logo.leadingAnchor == $0.leadingAnchor
            logo.trailingAnchor == $0.trailingAnchor
            logo.heightAnchor == 270

        }
    }

    func setupLocalization() {
        descriptionLabel.attributedText = R.string.localizable
            .friendsSpreadWord(preferredLanguages: languages)
            .styled(.paragraph1)

        title = R.string.localizable.inviteFragmentTitle(preferredLanguages: localizationManager?.preferredLocalizations)
        label.text = R.string.localizable.friendsSpreadWord(preferredLanguages: localizationManager?.preferredLocalizations)
    }

    @objc func copyAction() {
        presenter.didSelectAction(.copyInviteCode)
    }

    @objc func shareInviteAction() {
        presenter.didSelectAction(.sendInvite)
    }

    @objc func applyInviteAction() {
        presenter.didSelectAction(.enterCode)
    }
}

// MARK: - RewardsSuperviewProtocol

extension FriendsViewController: RewardsSuperviewProtocol {
    var maximumHeightLimit: CGFloat {
        return view.frame.height - navigationBarHeightCorrection
    }

    var middleHeightLimit: CGFloat {
        return view.frame.height - containerView.frame.maxY
    }

    var minimumHeightLimit: CGFloat {
        return bottomContainerView.frame.height
    }

    var prefferedSize: CGSize {
        return CGSize(
            width: UIScreen.main.bounds.width,
            height: view.frame.height - statusBarHeightCorrection
        )
    }
}

// MARK: - FriendsViewProtocol

extension FriendsViewController: FriendsViewProtocol {
    func didReceive(friendsViewModel: FriendsInvitationViewModelProtocol) {
        self.friendsViewModel = friendsViewModel
    }

    func didReceive(rewardsViewModels: [RewardsViewModelProtocol]) {
        rewardsViewController.bind(rewardsViewModels: rewardsViewModels)
    }

    func didChange(applyInviteTitle: String) {
        //applyInviteButton.setTitle(applyInviteTitle, for: .normal)
        applyInviteButton.imageWithTitleView?.title = applyInviteTitle
    }
}

// MARK: - Localizable

extension FriendsViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    private var shareInviteTitle: String {
        return R.string.localizable
            .inviteLinkSharingTitle(preferredLanguages: languages)
    }

    private var applyInviteTitle: String {
        return R.string.localizable
            .inviteCodeApply(preferredLanguages: languages)
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
