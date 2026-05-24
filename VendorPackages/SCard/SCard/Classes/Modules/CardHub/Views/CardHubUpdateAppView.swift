import UIKit
import SoraUIKit

final class CardHubUpdateAppView: SoramitsuView {

    var onUpdate: (() -> Void)?

    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.numberOfLines = 2
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.soraCard.cardHubUpdateTitle(preferredLanguages: .currentLocale)
        return label
    }()

    private let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphS
        label.sora.textColor = .fgSecondary
        label.sora.numberOfLines = 0
        label.sora.text = R.string.soraCard.cardHubUpdateDescription(preferredLanguages: .currentLocale)
        return label
    }()

    private lazy var attentionIcon: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.sora.picture = .logo(image: R.image.attention() ?? UIImage())
        return view
    }()

    private lazy var updateView: SoramitsuView = {
        let label = SoramitsuView()
        label.sora.backgroundColor = .accentPrimary
        label.sora.cornerRadius = .medium
        label.addTapGesture { [weak self] _ in
            self?.onUpdate?()
        }
        return label
    }()

    private lazy var updateLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldS
        label.sora.textColor = .bgSurface
        label.sora.text = R.string.soraCard.cardHubUpdateButton(preferredLanguages: .currentLocale)
        return label
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

    private func setupInitialLayout() {

        addSubview(titleLabel) {
            $0.top.leading.equalToSuperview().inset(24)
        }

        addSubview(attentionIcon) {
            $0.top.trailing.equalToSuperview().inset(24)
            $0.leading.equalTo(titleLabel.snp.trailing).offset(16)
            $0.size.equalTo(24)
        }

        addSubview(subtitleLabel) {
            $0.top.equalTo(titleLabel.snp.bottom).offset(16)
            $0.leading.trailing.equalToSuperview().inset(24)
        }

        updateView.addSubview(updateLabel) {
            $0.top.bottom.equalToSuperview().inset(8)
            $0.leading.trailing.equalToSuperview().inset(12)
        }

        addSubview(updateView) {
            $0.top.equalTo(subtitleLabel.snp.bottom).offset(16)
            $0.leading.bottom.equalToSuperview().inset(24)
        }
    }
}
