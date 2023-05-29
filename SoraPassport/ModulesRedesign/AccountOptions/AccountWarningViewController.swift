import Foundation
import SoraFoundation
import SoraUIKit
import Anchorage

final class AccountWarningViewController: SoramitsuViewController, ControllerBackedProtocol {

    var completion: (() -> ())?

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
            $0.spacing = 8
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

    var submitButton: SoramitsuButton = {
        SoramitsuButton().then {
            $0.sora.isEnabled = false
            $0.sora.cornerRadius = .circle
            $0.addTarget(nil, action: #selector(completeTapped), for: .touchUpInside)
        }
    }()


    override func viewDidLoad() {
        super.viewDidLoad()
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        configure()
    }

    private func configure() {
        navigationItem.backButtonTitle = ""
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = R.string.localizable.commonPayAttention(preferredLanguages: languages)
        titleLabel.sora.text = R.string.localizable.exportProtectionPassphraseDescription(preferredLanguages: languages)
        view.addSubview(containerView)

        let warnings = [
            R.string.localizable.exportProtectionPassphrase1(preferredLanguages: languages),
                        R.string.localizable.exportProtectionPassphrase2(preferredLanguages: languages),
                        R.string.localizable.exportProtectionPassphrase3(preferredLanguages: languages)
        ]

        stackView.removeArrangedSubviews()
        containerView.addSubview(stackView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubviews(
            warnings.map{
                CheckView(title: $0).then{
                    $0.addTapGesture { [weak self] recognizer in
                        self?.checkBoxTapped(sender: recognizer.view as? CheckView)
                    }
                }
            }
        )
        stackView.setCustomSpacing(24, after: stackView.arrangedSubviews.last!)
        stackView.addArrangedSubview(submitButton)
        stackView.setCustomSpacing(20, after: titleLabel)
        containerView.do {
            $0.horizontalAnchors == view.horizontalAnchors + 16
            $0.topAnchor == view.soraSafeTopAnchor

        }
        stackView.do {
            $0.horizontalAnchors == containerView.horizontalAnchors + 24
            $0.verticalAnchors == containerView.verticalAnchors + 24
        }
    }

    var selectionCount = 0 {
        didSet {
            submitButton.sora.isEnabled = selectionCount == 3
        }
    }

    func checkBoxTapped(sender: CheckView?){
        guard let check = sender else { return }

        check.isSelected = !check.isSelected
        if check.isSelected {
            selectionCount += 1
        } else {
            selectionCount -= 1
        }
    }

    @objc
    func completeTapped(){
        completion?()
    }
}

extension AccountWarningViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        submitButton.sora.title = R.string.localizable.transactionContinue(preferredLanguages: languages)
    }
}

final class CheckView: SoramitsuView {

    private lazy var checkView: SoramitsuImageView = {
        SoramitsuImageView().then {
            $0.sora.borderColor = .fgPrimary
            $0.sora.cornerRadius = .circle
            $0.sora.clipsToBounds = true
            $0.sora.borderWidth = 1
            $0.clipsToBounds = true
        }

    }()

    private lazy var textLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.numberOfLines = 0
            $0.sora.lineBreakMode = .byWordWrapping
        }
    }()

    var isSelected: Bool = false {
        didSet {
            checkView.image = isSelected ? R.image.checkboxSelected() : nil
            checkView.sora.borderWidth = isSelected ? 0 : 1
            sora.borderColor = isSelected ? .accentPrimary : .bgSurfaceVariant
        }
    }
    

    init(title: String) {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        addSubview(checkView)
        addSubview(textLabel)

        sora.cornerRadius = .large
        sora.backgroundColor = .bgSurface
        sora.borderColor = isSelected ? .accentPrimary : .bgSurfaceVariant
        sora.borderWidth = 1

        self.heightAnchor >= 56

        checkView.do {
            $0.sizeAnchors == CGSize(width: 24, height: 24)
            $0.leadingAnchor == leadingAnchor + 16
            $0.centerYAnchor == centerYAnchor
        }

        textLabel.do {
            $0.verticalAnchors == verticalAnchors + 8
            $0.leadingAnchor == checkView.trailingAnchor + 16
            $0.trailingAnchor == trailingAnchor - 16
            $0.sora.text = title
            $0.sora.font = FontType.textS
            $0.sora.textColor = .fgPrimary
        }

    }
}
