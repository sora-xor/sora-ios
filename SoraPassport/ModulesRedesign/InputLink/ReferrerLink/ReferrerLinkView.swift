import UIKit
import SoraUIKit
import SnapKit


final class ReferrerLinkView: SoramitsuView {

    private lazy var stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.axis = .vertical
        stackView.sora.backgroundColor = .custom(uiColor: .clear)
        stackView.sora.distribution = .fill
        stackView.spacing = 0
        return stackView
    }()
    
    private lazy var titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.referralReferralLink(preferredLanguages: .currentLocale)
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textXS
        return label
    }()
    
    let textField: SoramitsuTextField = {
        let textField = SoramitsuTextField()
        textField.sora.backgroundColor = .custom(uiColor: .clear)
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        return textField
    }()
    
    init() {
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension ReferrerLinkView {
    func configure() {
        sora.backgroundColor = .custom(uiColor: .clear)
        sora.cornerRadius = .max
        sora.cornerMask = .all
        sora.borderColor = .fgPrimary
        sora.borderWidth = 1.0
        
        addSubview(stackView)
        stackView.addArrangedSubviews([titleLabel, textField])
        
        stackView.snp.makeConstraints { make in
            make.top.equalTo(self).offset(14)
            make.leading.equalTo(self).offset(16)
            make.center.equalTo(self)
        }
    }
}
