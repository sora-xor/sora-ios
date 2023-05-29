import UIKit
import SoraFoundation
import SoraUI
import SoraUIKit
import Anchorage

final class AccountCreateViewController: SoramitsuViewController {
    enum Mode {
        case registration
        case view
    }

    var presenter: AccountCreatePresenterProtocol!

    private let containerView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.shadow = .default
        view.spacing = 24
        view.sora.cornerRadius = .max
        view.sora.distribution = .fill
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    private let titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.paragraphM
            $0.sora.textColor = .fgPrimary
            $0.numberOfLines = 0
        }
    }()

    private let mnemonicView: MnemonicDisplayView = {
        MnemonicDisplayView(frame: .zero).then {
            $0.indexTitleColorInColumn = .fgPrimary
            $0.wordTitleColorInColumn = .fgPrimary
            $0.indexFontInColumn = ScreenSizeMapper.value(small: FontType.textS, medium: FontType.textL, large: FontType.textL)
            $0.wordFontInColumn =  ScreenSizeMapper.value(small: FontType.textBoldS, medium: FontType.textBoldL, large: FontType.textBoldL)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    private var shareButton: SoramitsuButton = {
        SoramitsuButton(size: .large, type: .tonal(.tertiary)).then {
            $0.sora.leftImage = R.image.copyNeu()
            $0.addTarget(nil, action: #selector(actionShare), for: .touchUpInside)
            $0.sora.cornerRadius = .circle
        }
    }()

    private var nextButton: SoramitsuButton = {
        SoramitsuButton().then {
            $0.sora.cornerRadius = .circle
            $0.addTarget(nil, action: #selector(actionNext), for: .touchUpInside)
        }
    }()
    
    private var skipButton: SoramitsuButton = {
        SoramitsuButton().then {
            $0.sora.cornerRadius = .circle
            $0.addTarget(nil, action: #selector(actionSkip), for: .touchUpInside)
            $0.sora.backgroundColor = .accentPrimaryContainer
        }
    }()

    var mode: Mode = .registration

    private var derivationPathModel: InputViewModelProtocol?

    var keyboardHandler: KeyboardHandler?

    var advancedAppearanceAnimator = TransitionAnimator(type: .push,
                                                        duration: 0.35,
                                                        subtype: .fromBottom,
                                                        curve: .easeOut)

    var advancedDismissalAnimator = TransitionAnimator(type: .push,
                                                       duration: 0.35,
                                                       subtype: .fromTop,
                                                       curve: .easeIn)

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.backButtonTitle = ""

        setupNavigationItem()
        setupLocalization()
        configure()

        presenter.setup()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appEnterToForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc
    func appEnterToForeground() {
        presenter?.restoredApp()
    }

    private func configure() {

        view.addSubview(containerView)
        containerView.addArrangedSubviews([
            titleLabel,
            mnemonicView,
            shareButton,
            nextButton,
            skipButton
        ])

        containerView.setCustomSpacing(16, after: nextButton)
        containerView.do {
            $0.topAnchor == view.soraSafeTopAnchor
            $0.bottomAnchor <= view.soraSafeBottomAnchor
            $0.horizontalAnchors == view.horizontalAnchors + 16
        }

        view.backgroundColor = .clear

        shareButton.isHidden = mode == .registration
        skipButton.isHidden = mode == .view
        nextButton.isHidden = !shareButton.isHidden
    }

    private func setupNavigationItem() {
        let infoItem = UIBarButtonItem(image: R.image.linkInfo(),
                                       style: .plain,
                                       target: self,
                                       action: #selector(actionOpenInfo))
        navigationItem.rightBarButtonItem = mode == .view ? infoItem : nil
        navigationItem.rightBarButtonItem?.tintColor = SoramitsuUI.shared.theme.palette.color(.accentTertiary)
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        title = R.string.localizable.mnemonicTitle(preferredLanguages: locale.rLanguages).capitalized
        titleLabel.sora.text = R.string.localizable.mnemonicText(preferredLanguages: locale.rLanguages)
        nextButton.sora.title = R.string.localizable
            .transactionContinue(preferredLanguages: locale.rLanguages)
        shareButton.sora.title = R.string.localizable
            .copyToClipboard(preferredLanguages: locale.rLanguages)
        
        let skipText = R.string.localizable.commonSkip(preferredLanguages: locale.rLanguages).uppercased()
        skipButton.sora.attributedText = SoramitsuTextItem(text: skipText,
                                                           fontData: FontType.buttonM ,
                                                           textColor: .accentPrimary,
                                                           alignment: .center)
    }

    @IBAction private func actionNext() {
        presenter.proceed()
    }

    @IBAction private func actionShare() {
        shareButton.sora.title = R.string.localizable.commonCopied(preferredLanguages: .currentLocale)
        presenter.share()
    }
    
    @objc private func actionOpenInfo() {
        presenter.activateInfo()
    }

    @objc private func actionSkip() {
        presenter.skip()
    }
}

extension AccountCreateViewController: AccountCreateViewProtocol {
    func set(mnemonic: [String]) {
        var conditionedMnemonic = mnemonic
        if mnemonic.count % 2 == 1 {
            conditionedMnemonic.append("") //Quick fix for legacy 15-word mnemonics
        }
        mnemonicView.bind(words: conditionedMnemonic, columnsCount: 2)
    }
}

extension AccountCreateViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
