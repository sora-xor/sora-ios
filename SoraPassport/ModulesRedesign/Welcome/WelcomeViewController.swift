import UIKit
import SoraUIKit
import Nantes

final class WelcomeViewController: SoramitsuViewController, OnboardingMainViewProtocol {
    var presenter: OnboardingMainPresenterProtocol!
    
    let logo: SoramitsuImageView = {
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
        view.sora.clipsToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let titleLabel: SoramitsuLabel = {
        let title = SoramitsuTextItem(text:  R.string.localizable.tutorialManyWorld(preferredLanguages: .currentLocale),
                                      fontData: ScreenSizeMapper.value(small: FontType.displayS, medium: FontType.displayL, large: FontType.displayL),
                                      textColor: .fgPrimary,
                                      alignment: .center)
        
        let sora = SoramitsuTextItem(text:  "\nSORA",
                                     fontData: ScreenSizeMapper.value(small: FontType.displayS, medium: FontType.displayL, large: FontType.displayL),
                                     textColor: .accentPrimary,
                                     alignment: .center)
        let label = SoramitsuLabel()
        label.sora.numberOfLines = 0
        label.sora.attributedText = [ title, sora ]
        return label
    }()
    
    let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.numberOfLines = 0
        label.sora.font = FontType.paragraphS
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.localizable.onboardingDescription(preferredLanguages: .currentLocale)
        label.sora.alignment = .center
        return label
    }()
    
    private lazy var googleButton: SoramitsuButton = {
        let title = SoramitsuTextItem(text: R.string.localizable.onboardingContinueWithGoogle(preferredLanguages: .currentLocale),
                                      fontData: FontType.buttonM,
                                      textColor: .accentSecondary,
                                      alignment: .center)
        
        let button = SoramitsuButton()
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .custom(uiColor: .clear)
        button.sora.attributedText = title
        button.sora.imageSize = 37
        button.sora.leftImage = R.image.googleIcon()
        button.sora.borderColor = .accentSecondary
        button.sora.borderWidth = 1
        button.sora.isHidden = true
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.presenter.activateCloudStorageConnection()
        }
        return button
    }()
    
    private lazy var createAccountButton: SoramitsuButton = {
        let title = SoramitsuTextItem(text: R.string.localizable.create_account_title(preferredLanguages: .currentLocale),
                                      fontData: FontType.buttonM,
                                      textColor: .bgSurface,
                                      alignment: .center)
        
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .accentPrimary
        button.sora.attributedText = title
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.presenter.activateSignup()
        }
        return button
    }()
    
    private lazy var importAccountButton: SoramitsuButton = {
        let title = SoramitsuTextItem(text: R.string.localizable.recoveryTitleV2(preferredLanguages: .currentLocale),
                                      fontData: FontType.buttonM,
                                      textColor: .accentPrimary,
                                      alignment: .center)
        
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .custom(uiColor: .clear)
        button.sora.attributedText = title
        button.sora.borderColor = .accentPrimary
        button.sora.borderWidth = 1
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.presenter.activateAccountRestore()
        }
        return button
    }()
    
    lazy var termDecorator: AttributedStringDecoratorProtocol = {
        CompoundAttributedStringDecorator.legalRedesign(for: Locale.current)
    }()
    
    public lazy var termsLabel: NantesLabel = {
        let label = NantesLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text =  R.string.localizable.tutorialTermsAndConditionsRecovery(preferredLanguages: .currentLocale)
        label.delegate = self
        return label
    }()
    
    let linkDecorator = LinkDecoratorFactory.termsDecorator()
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.backButtonTitle = ""
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        setupView()
        setupConstraints()
        presenter.setup()
    }
    
    func setupView() {
        view.addSubview(containerView)
        containerView.addSubviews(logo, titleLabel, subtitleLabel, googleButton, createAccountButton, importAccountButton, termsLabel)
        decorate(label: termsLabel)
    }
    
    func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            logo.topAnchor.constraint(equalTo: containerView.topAnchor, constant: -56),
            logo.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 80),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            subtitleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            createAccountButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            createAccountButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            createAccountButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            importAccountButton.topAnchor.constraint(equalTo: createAccountButton.bottomAnchor, constant: 16),
            importAccountButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            importAccountButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            termsLabel.topAnchor.constraint(equalTo: importAccountButton.bottomAnchor, constant: 16),
            termsLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            termsLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            termsLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
        ])
    }
}

extension WelcomeViewController: NantesLabelDelegate {
    func attributedLabel(_ label: NantesLabel, didSelectLink link: URL) {
        UIApplication.shared.open(link, options: [:], completionHandler: nil)
    }
}
