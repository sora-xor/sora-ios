import Foundation
import WebKit
import UIKit
import SoraUIKit

final class XOneBlockedViewController: UIViewController {

    var onClose: (() -> Void)?
    var onUnsupportedCountries: (() -> Void)?
    var onAction: (() -> Void)?

    override func loadView() {
        super.loadView()
        let view = SCXOneBlockedView()
        view.onCloseButton = onClose
        view.onUnsupportedCountriesButton = onUnsupportedCountries
        view.onActionButton = onAction

        self.view = view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = R.string.soraCard.paymentWidgetUnavailableTitle(preferredLanguages: .currentLocale)
    }
}


final class SCXOneBlockedView: UIView {

    var onCloseButton: (() -> Void)?
    var onUnsupportedCountriesButton: (() -> Void)?
    var onActionButton: (() -> Void)?

    private let iconView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.sora.contentMode = .scaleAspectFit
        view.sora.picture = .logo(image: R.image.xOneBlocked()!)
        return view
    }()

    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.soraCard.paymentWidgetUnavailableMessage(preferredLanguages: .currentLocale)
        label.sora.font = FontType.headline1
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .center
        label.sora.numberOfLines = 0
        return label
    }()

    private let textLabel: SoramitsuLabel = {

        let label = SoramitsuLabel()
        label.sora.text = R.string.soraCard.paymentWidgetUnavailableDescription(preferredLanguages: .currentLocale)
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .center
        label.sora.numberOfLines = 0
        return label
    }()

    private lazy var unsupportedCountriesButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .text(.primary))
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onUnsupportedCountriesButton?()
        }
        button.sora.title = R.string.soraCard.unsupportedCountriesLink(preferredLanguages: .currentLocale)

        let text = R.string.soraCard.unsupportedCountriesLink(preferredLanguages: .currentLocale)
        button.sora.attributedText = SoramitsuTextItem(text: text, fontData: FontType.paragraphXS, textColor: .accentPrimary, alignment: .center, underline: .single)

        button.snp.makeConstraints {
            $0.height.equalTo(30)
        }

        return button
    }()

    private lazy var actionButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .filled(.secondary))
        button.sora.attributedText = SoramitsuTextItem(
            text: R.string.soraCard.paymentWidgetUnavailableConfirm(preferredLanguages: .currentLocale),
            fontData: FontType.buttonM,
            textColor: .bgSurface,
            alignment: .center
        )
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onActionButton?()
        }
        button.sora.cornerRadius = .custom(28)
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgPage)
        setupInitialLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupInitialLayout() {

        iconView.snp.makeConstraints {
            $0.size.equalTo(80)
        }

        let stackView = UIStackView(arrangedSubviews: [
            iconView,
            titleLabel,
            textLabel,
            unsupportedCountriesButton
        ])
        stackView.axis = .vertical
        stackView.spacing = UIScreen.main.isSmallSizeScreen ? 8 : 24

        addSubview(stackView) {
            $0.leading.trailing.equalToSuperview().inset(24)
            $0.centerY.equalToSuperview()
        }

        addSubview(actionButton) {
            $0.leading.trailing.equalToSuperview().inset(24)
            $0.bottom.equalTo(self.safeAreaLayoutGuide).inset(24)
        }
    }
}

fileprivate extension UIScreen {
    var isSmallSizeScreen: Bool {
        bounds.height <= 640
    }
}
