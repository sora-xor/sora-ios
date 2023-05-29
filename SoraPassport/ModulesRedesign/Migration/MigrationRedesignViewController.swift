import UIKit
import Anchorage
import Then
import SoraUI
import SoraUIKit
import Nantes

protocol MigrationViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func resetState()
}

enum MigrationState {
    case normal
    case loading
    
    var title: String? {
        return self == .normal ? nil : R.string.localizable.claimSubtitleConfirmed(preferredLanguages: .currentLocale)
    }
    
    var subtitle: String {
        if self == .normal {
            return R.string.localizable.claimSubtitleV2(preferredLanguages: .currentLocale)
        }
        return R.string.localizable.claimSubtitleConfirmedV2(preferredLanguages: .currentLocale)
    }
    
    var subtitleAligment: NSTextAlignment {
        if self == .normal {
            return .left
        }
        return .center
    }
}

class MigrationRedesignViewController: SoramitsuViewController {
    var presenter: MigrationPresenter!
    
    var state: MigrationState = .normal {
        didSet {
            titleLabel.sora.text = state.title
            titleLabel.sora.isHidden = state == .normal
            subtitleLabel.sora.text = state.subtitle
            subtitleLabel.sora.alignment = state.subtitleAligment
            
            signUpButton.sora.isHidden = state == .loading
            loadingView.sora.isHidden = state == .normal
            loadingView.rotate()
        }
    }

    var locale: Locale?
    
    let logoImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.image = R.image.soraLogoBig()
        view.sora.cornerRadius = .circle
        view.sora.backgroundColor = .bgSurface
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 112).isActive = true
        view.widthAnchor.constraint(equalToConstant: 112).isActive = true
        return view
    }()
    
    let containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.shadow = .small
        view.sora.clipsToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let headerLabel: SoramitsuLabel = {
        let title = SoramitsuTextItem(text:  R.string.localizable.claimWelcomeToV1(preferredLanguages: .currentLocale),
                                      fontData: ScreenSizeMapper.value(small: FontType.displayS, medium: FontType.displayL, large: FontType.displayL),
                                      textColor: .fgPrimary,
                                      alignment: .center)
        
        let sora = SoramitsuTextItem(text:  "\nSORA v2",
                                     fontData: ScreenSizeMapper.value(small: FontType.displayS, medium: FontType.displayL, large: FontType.displayL),
                                     textColor: .accentPrimary,
                                     alignment: .center)
        
        let label = SoramitsuLabel()
        label.sora.numberOfLines = 0
        label.sora.attributedText = [ title, sora ]
        return label
    }()
    
    private let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .vertical
        view.sora.distribution = .fill
        view.spacing = 16
        return view
    }()
    
    lazy var titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.numberOfLines = 0
        label.sora.font = FontType.headline3
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.localizable.claimSubtitleV2(preferredLanguages: .currentLocale)
        label.sora.alignment = .center
        label.sora.isHidden = true
        return label
    }()
    
    lazy var subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.numberOfLines = 0
        label.sora.font = FontType.paragraphS
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.localizable.claimSubtitleV2(preferredLanguages: .currentLocale)
        label.sora.alignment = .left
        return label
    }()
    
    private lazy var signUpButton: SoramitsuButton = {
        let title = SoramitsuTextItem(text: R.string.localizable
            .commonConfirm(preferredLanguages: .currentLocale),
                                      fontData: FontType.buttonM,
                                      textColor: .bgSurface,
                                      alignment: .center)
        
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .accentPrimary
        button.sora.attributedText = title
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.state = .loading
            self?.presenter.proceed()
        }
        return button
    }()
    
    let loadingView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .custom(uiColor: UIColor(hex: "#281818", alpha: 0.04))
        view.sora.cornerRadius = .circle
        view.sora.shadow = .small
        view.sora.clipsToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 56).isActive = true
        view.widthAnchor.constraint(equalToConstant: 56).isActive = true
        view.sora.isHidden = true
        return view
    }()

    let loadingImageView: SoramitsuImageView = {
        let picture: Picture = .icon(image: R.image.wallet.loading()!,
                                     color: .custom(uiColor: UIColor(hex: "#28303F", alpha: 0.24)))
        let view = SoramitsuImageView()
        view.sora.picture = picture
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 24).isActive = true
        view.widthAnchor.constraint(equalToConstant: 24).isActive = true
        return view
    }()

    let linkDecorator = LinkDecoratorFactory.disclaimerDecorator()
    
    public let privacyLabel: NantesLabel = {
        let label = NantesLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = R.string.localizable.claimContactUs(preferredLanguages: .currentLocale)
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.backButtonTitle = ""
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        setupView()
        setupConstraints()

    }

    func setupView() {
        view.addSubview(containerView)
        loadingView.addSubviews(loadingImageView)
        stackView.addArrangedSubviews(titleLabel, subtitleLabel)
        containerView.addSubviews(logoImageView, headerLabel, stackView, loadingView, signUpButton, privacyLabel)
        decorate(label: privacyLabel)
    }

    func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            logoImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: -56),
            logoImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            headerLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 80),
            headerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            headerLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            stackView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            stackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            signUpButton.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 24),
            signUpButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            signUpButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            loadingView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            loadingView.centerXAnchor.constraint(equalTo: signUpButton.centerXAnchor),
            
            loadingImageView.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            loadingImageView.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor),
            
            privacyLabel.topAnchor.constraint(equalTo: signUpButton.bottomAnchor, constant: 16),
            privacyLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            privacyLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            privacyLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
        ])
    }
    
    func decorate(label: NantesLabel) {
        label.delegate = self
        label.linkAttributes = [
            NSAttributedString.Key.foregroundColor: SoramitsuUI.shared.theme.palette.color(.accentPrimary)
        ]
        var text = label.text ?? ""
        let links: [(URL, NSRange)] = linkDecorator.links(inText: &text)
        
        let attributedText = SoramitsuTextItem(text: text,
                                     fontData: FontType.textXS,
                                     textColor: .fgPrimary,
                                     alignment: .center).attributedString
        
        label.attributedText = attributedText
        for link in links {
            label.addLink(to: link.0, withRange: link.1)
        }
    }
}

extension MigrationRedesignViewController: NantesLabelDelegate {
    func attributedLabel(_ label: NantesLabel, didSelectLink link: URL) {
        presenter.activateTerms()
    }
}

// MARK: - Texts

private extension MigrationRedesignViewController {

}

extension MigrationRedesignViewController: MigrationViewProtocol {
    func resetState() {
        state = .normal
    }
}
