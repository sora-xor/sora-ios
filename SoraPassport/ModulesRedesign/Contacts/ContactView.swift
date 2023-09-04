import SoraUIKit
import Anchorage
import SnapKit

final class ContactView: SoramitsuView {
    
    public var onTap: (() -> Void)?
    
    public let accountImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.sora.tintColor = .fgSecondary
        imageView.sora.shadow = .extraSmall
        imageView.sora.cornerRadius = .circle
        imageView.sora.backgroundColor = .bgSurface
        return imageView
    }()
    
    public let accountTitle: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgPrimary
        label.sora.font = FontType.textS
        label.sora.numberOfLines = 2
        label.sora.text = R.string.localizable.selectRecipient(preferredLanguages: .currentLocale)
        return label
    }()
    
    public let usernameTitle: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textBoldXS
        label.sora.numberOfLines = 1
        return label
    }()
    
    public let arrowImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.image = R.image.wallet.rightArrow()
        imageView.sora.tintColor = .fgSecondary
        return imageView
    }()
    
    public lazy var button: SoramitsuButton = {
        let view = SoramitsuButton()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.isHidden = true
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.onTap?()
        }
        return view
    }()
    
    private let contactStackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.axis = .vertical
        stackView.sora.distribution = .equalSpacing
        stackView.spacing = 4
        return stackView
    }()
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }

    private func setupSubviews() {
        sora.backgroundColor = .bgSurface
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(accountImageView)
        addSubview(arrowImageView)
        addSubview(contactStackView)
        addSubview(button)
        
        contactStackView.addArrangedSubviews([usernameTitle, accountTitle])
    }

    private func setupConstrains() {
        accountImageView.snp.makeConstraints { make in
            make.height.equalTo(40)
            make.width.equalTo(40)
            make.top.equalTo(self).offset(8)
            make.leading.equalTo(self).offset(24)
            make.centerY.equalTo(self)
        }
        
        arrowImageView.snp.makeConstraints { make in
            make.height.equalTo(24)
            make.width.equalTo(24)
            make.trailing.equalTo(self).offset(-16)
            make.centerY.equalTo(accountImageView)
        }
        
        contactStackView.snp.makeConstraints { make in
            make.leading.equalTo(accountImageView.snp.trailing).offset(8)
            make.trailing.equalTo(arrowImageView.snp.leading).offset(-8)
            make.centerY.equalTo(accountImageView)
        }
        
        button.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}
