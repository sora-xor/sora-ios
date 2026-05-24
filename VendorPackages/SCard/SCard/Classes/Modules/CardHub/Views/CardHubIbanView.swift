import UIKit
import SoraUIKit

final class CardHubIbanView: SoramitsuView {

    var onIbanShare: ((String) -> Void)?
    var onIbanCopy: ((String) -> Void)?

    private let supportLink = SCard.techSupportLink

    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.text = R.string.soraCard.cardhubIbanTitle(preferredLanguages: .currentLocale)
        return label
    }()

    var tapGesture: SoramitsuTapGestureRecognizer?
    private lazy var subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.text = ""
        label.isUserInteractionEnabled = true
        return label
    }()

    private lazy var shareButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .bleached(.tertiary))
        button.sora.tintColor = .accentTertiary
        button.sora.backgroundColor = .custom(uiColor: .clear)
        button.sora.leftImage = R.image.upload()
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onIbanShare?(self?.subtitleLabel.sora.text ?? "")
        }
        return button
    }()

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.clipsToBounds = false
        self.sora.backgroundColor = .bgSurface
        self.sora.shadow = .default
        self.sora.cornerRadius = .max
        setupInitialLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(iban: String?, ibanStatus: Iban.Status?) {

        if let tapGesture = tapGesture {
            subtitleLabel.removeGestureRecognizer(tapGesture)
        }

        if let iban = iban, ibanStatus == .active {
            shareButton.sora.isHidden = false
            subtitleLabel.sora.text = iban
            subtitleLabel.sora.textColor = .fgPrimary
            tapGesture = subtitleLabel.addTapGesture { [weak self] _ in
                self?.onIbanCopy?(self?.subtitleLabel.sora.text ?? "")
            }
        } else {
            shareButton.sora.isHidden = true

            let text: String
            switch ibanStatus {
            case .active, .none:
                text = R.string.soraCard.ibanPendingDescription(supportLink, preferredLanguages: .currentLocale)
            case .suspendedByUser:
                text = R.string.soraCard.ibanFrozenDescription(supportLink, preferredLanguages: .currentLocale)
            case .suspendedBySystem, .closed:
                text = R.string.soraCard.ibanFrozenDescription(supportLink, preferredLanguages: .currentLocale)
            }

            let palette = SoramitsuUI.shared.theme.palette
            let attributedString = NSMutableAttributedString(
                string: text,
                attributes: [
                    NSAttributedString.Key.foregroundColor: palette.color(.fgSecondary),
                    NSAttributedString.Key.font: FontType.textM.font
                ]
            )
            _ = attributedString.addUrl(link: "mailto:\(supportLink)", to: supportLink)

            subtitleLabel.sora.attributedText = attributedString
            tapGesture = subtitleLabel.addTapGesture { [weak self] _ in
                guard
                    let mail = self?.supportLink,
                    let url = URL(string: "mailto:\(mail)")
                else { return }
                UIApplication.shared.open(url)
            }
        }
    }

    private func setupInitialLayout() {

        addSubview(titleLabel) {
            $0.top.leading.equalToSuperview().inset(24)
        }

        addSubview(shareButton) {
            $0.top.equalToSuperview().inset(4)
            $0.trailing.equalToSuperview().inset(24)
            $0.leading.equalTo(titleLabel.snp.trailing).offset(16)
            $0.width.equalTo(32)
        }

        addSubview(subtitleLabel) {
            $0.top.equalTo(titleLabel.snp.bottom).offset(16)
            $0.bottom.leading.trailing.equalToSuperview().inset(24)
        }
    }
}

extension NSMutableAttributedString {
    public func addUrl(link: String, to text: String) -> Bool {
        let range = self.mutableString.range(of: text)
        guard range.location != NSNotFound else { return false }
        // self.addAttribute(.link, value: link, range: range)
        self.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        return true
    }
}
