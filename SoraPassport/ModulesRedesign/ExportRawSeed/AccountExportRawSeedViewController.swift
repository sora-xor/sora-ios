import Foundation
import SoraFoundation
import SoraUIKit
import Anchorage

final class AccountExportRawSeedViewController: SoramitsuViewController, ControllerBackedProtocol {

    var presenter: AccountExportRawSeedPresenterProtocol!

    private var containerView: SoramitsuView = {
        SoramitsuView().then {
            $0.sora.backgroundColor = .bgSurface
            $0.sora.cornerRadius = .max
            $0.layer.masksToBounds = true
            $0.sora.shadow = .default
        }
    }()

    private var stackView: SoramitsuStackView = {
        SoramitsuStackView().then {
            $0.sora.axis = .vertical
            $0.spacing = 24
            $0.layer.cornerRadius = 0
            $0.sora.distribution = .fill
        }
    }()

    private var titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.textM
            $0.sora.textColor = .fgPrimary
            $0.numberOfLines = 0
        }
    }()

    private var descriptionLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.paragraphBoldM
            $0.sora.textColor = .fgPrimary
            $0.numberOfLines = 0
        }
    }()

    private var copyButton: SoramitsuButton = {
        SoramitsuButton(size: .large, type: .tonal(.tertiary)).then {
            $0.sora.leftImage = R.image.copyNeu()
            $0.addTarget(nil, action: #selector(copyTapped), for: .touchUpInside)
            $0.sora.cornerRadius = .circle
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        configure()
        presenter.exportRawSeed()
    }

    func set(rawSeed: String) {
        descriptionLabel.sora.text = rawSeed
    }

    private func configure() {
        navigationItem.backButtonTitle = ""
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = R.string.localizable.commonRawSeed(preferredLanguages: languages)
        titleLabel.sora.text = R.string.localizable.mnemonicText(preferredLanguages: languages)

        view.addSubview(containerView)

        stackView.removeArrangedSubviews()
        containerView.addSubview(stackView)
        stackView.addArrangedSubviews([
            titleLabel,
            descriptionLabel,
            copyButton
        ])
        containerView.do {
            $0.horizontalAnchors == view.horizontalAnchors + 16
            $0.topAnchor == view.soraSafeTopAnchor
        }
        stackView.do {
            $0.horizontalAnchors == containerView.horizontalAnchors + 24
            $0.verticalAnchors == containerView.verticalAnchors + 24
        }
    }

    @objc
    private func copyTapped(){
        copyButton.sora.title = R.string.localizable.commonCopied(preferredLanguages: .currentLocale)
        presenter.copyRawSeed()
    }
}

extension AccountExportRawSeedViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        copyButton.sora.title = R.string.localizable.copyToClipboard(preferredLanguages: languages)
    }
}

extension AccountExportRawSeedViewController: AccountExportRawSeedViewProtocol {}
