import UIKit
import Anchorage
import Then
import SoraUI

protocol MigrationViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func resetState()
}

class MigrationViewController: UIViewController {
    struct Constants {
        static let logoWidth: CGFloat = 168
        static let logoHeight: CGFloat = 116
        static let logoFriction: CGFloat = 0.9
    }

    var presenter: MigrationPresenter!

    var locale: Locale?

    private var logoWidthConstraint: NSLayoutConstraint!
    private var logoHeightConstraint: NSLayoutConstraint!

    private lazy var logoImageView: UIImageView = {
        UIImageView(image: R.image.soraLogoBig()).then {
            logoWidthConstraint = ($0.widthAnchor == Constants.logoWidth)
            logoHeightConstraint = ($0.heightAnchor == Constants.logoWidth)
        }
    }()

    private lazy var termDecorator: AttributedStringDecoratorProtocol = { CompoundAttributedStringDecorator.contact(for: self.locale) }()

    private lazy var titleLabel: UILabel = {
        UILabel().then {
            $0.numberOfLines = 2
            $0.textAlignment = .center
            $0.font = UIFont.styled(for: .display1)
            $0.textColor = R.color.baseContentPrimary()
            $0.attributedText = titleTitle
        }
    }()

    private lazy var detailLabel: UILabel = {
        UILabel().then {
            $0.numberOfLines = 0
            $0.textAlignment = .natural
            $0.font = UIFont.styled(for: .paragraph1)
            $0.textColor = R.color.baseContentPrimary()
            $0.text = detailTitle
        }
    }()

    private lazy var privacyLabel: UILabel = {
        UILabel().then {
            $0.numberOfLines = 0
            $0.textAlignment = .center
            $0.font = UIFont.styled(for: .paragraph2)
            $0.textColor = R.color.baseContentPrimary()
            $0.attributedText = privacyTitle
            $0.isUserInteractionEnabled = true
            $0.addGestureRecognizer(tapGestureRecognizer)
        }
    }()

    private lazy var signUpButton: NeumorphismButton = {
        NeumorphismButton().then {
            $0.heightAnchor == 48
            $0.tintColor = R.color.brandWhite()
            $0.color = R.color.neumorphism.tint()!
            $0.buttonTitle = confirmTitle
            $0.addTarget(self, action: #selector(actionNext), for: .touchUpInside)
        }
    }()

    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        UITapGestureRecognizer(target: self, action: #selector(actionTerms(_:)))
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.largeTitleDisplayMode = .never
        configure()
    }

    func configure() {
        createContainerView().do {
            view.addSubview($0)
            $0.edgeAnchors.verticalAnchors == view.safeAreaLayoutGuide.edgeAnchors.verticalAnchors + 8
            $0.edgeAnchors.horizontalAnchors == view.safeAreaLayoutGuide.edgeAnchors.horizontalAnchors
        }
    }

    func createContainerView() -> UIView {
        UIStackView(arrangedSubviews: [
            createContentContainerView(),
            createPrivacyContainerView(),
            createButtonsContainerView()
        ]).then {
            $0.axis = .vertical
            $0.spacing = 16
        }
    }

    func createContentContainerView() -> UIView {
        let container = UIView().then {
            $0.addSubview(logoImageView)
            logoImageView.topAnchor == $0.topAnchor
            logoImageView.centerXAnchor == $0.centerXAnchor

            $0.addSubview(titleLabel)
            titleLabel.topAnchor == logoImageView.bottomAnchor + 18
            titleLabel.horizontalAnchors == $0.horizontalAnchors

            $0.addSubview(detailLabel)
            detailLabel.topAnchor == titleLabel.bottomAnchor + 8
            detailLabel.bottomAnchor == $0.bottomAnchor
            detailLabel.horizontalAnchors == $0.horizontalAnchors + 8
        }

        return UIView().then {
            $0.addSubview(container)
            container.centerAnchors == $0.centerAnchors
            container.horizontalAnchors == $0.horizontalAnchors + 16
        }
    }

    func createPrivacyContainerView() -> UIView {
        let container = UIView().then {
            $0.addSubview(privacyLabel)
            privacyLabel.topAnchor == $0.topAnchor
            privacyLabel.bottomAnchor == $0.bottomAnchor
            privacyLabel.horizontalAnchors == $0.horizontalAnchors
        }

        return UIView().then {
            $0.addSubview(container)
            container.verticalAnchors == $0.verticalAnchors
            container.horizontalAnchors == $0.horizontalAnchors + 8
        }
    }

    func createButtonsContainerView() -> UIView {
        let container = UIStackView(arrangedSubviews: [
            signUpButton
        ]).then {
            $0.axis = .vertical
            $0.spacing = 8
        }

        return UIView().then {
            $0.addSubview(container)
            container.verticalAnchors == $0.verticalAnchors
            container.horizontalAnchors == $0.horizontalAnchors + 8
        }
    }

    func resetState() {
        signUpButton.stopProgress()
        signUpButton.isEnabled = true
    }

    @IBAction private func actionNext() {
        presenter.proceed()
        signUpButton.startProgress()
        signUpButton.isEnabled = false
    }

    @IBAction func actionTerms(_ gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            let location = gestureRecognizer.location(in: privacyLabel.superview)

            if location.x < privacyLabel.center.x {
                presenter.activateTerms()
            } else {
                presenter.activatePrivacy()
            }
        }
    }
}

// MARK: - Texts

private extension MigrationViewController {
    var languages: [String]? {
        return locale?.rLanguages
    }

    var titleTitle: NSAttributedString {
        let baseText = R.string.localizable.claimWelcomeSora2V1(preferredLanguages: languages)
        let spl = baseText.nonEmptyComponents(separatedBy: String.lokalizableSeparator)
        let result = spl.reduce("", {$0+$1})
        let attributedText = result.decoratedWith([:], adding: [.foregroundColor: R.color.neumorphism.tint()!], to: [spl[1]])
        return attributedText
    }

    var detailTitle: String {
        return R.string.localizable
            .claimSubtitleV2(preferredLanguages: languages)
    }

    var privacyTitle: NSAttributedString? {
        let baseText = R.string.localizable
            .claimContactUs(preferredLanguages: locale?.rLanguages)
        let spl = baseText.nonEmptyComponents(separatedBy: String.lokalizableSeparator)
        let result = spl.reduce("", {$0+$1})
        let attributedText = result.decoratedWith([:], adding: [.foregroundColor: R.color.baseContentQuaternary()!, .underlineStyle: NSUnderlineStyle.single.rawValue ], to: [spl[0]])

        return attributedText 
    }

    var confirmTitle: String {
        return R.string.localizable
            .commonConfirm(preferredLanguages: languages).localizedUppercase
    }

}

extension MigrationViewController: MigrationViewProtocol {

}
