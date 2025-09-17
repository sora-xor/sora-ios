import Foundation
import SoraUIKit

public final class CardHubActionButtonView: SoramitsuView {

    public let button: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .bleached(.tertiary))
        button.sora.cornerRadius = .circle
        button.sora.shadow = .none
        button.sora.clipsToBounds = false
        return button
    }()

    public let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.alignment = .center
        return label
    }()

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setup() {
        addSubview(button) {
            $0.top.centerX.equalToSuperview()
            $0.leading.greaterThanOrEqualToSuperview()
            $0.trailing.lessThanOrEqualToSuperview()
            $0.size.equalTo(56)
        }
        addSubview(titleLabel) {
            $0.top.equalTo(button.snp.bottom).offset(8)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }
}
