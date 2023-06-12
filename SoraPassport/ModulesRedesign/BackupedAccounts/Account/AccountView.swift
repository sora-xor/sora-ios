import SoraUIKit
import Anchorage

final class AccountView: SoramitsuView {
    
    public var onTap: (() -> Void)?
    
    public var topConstraint: NSLayoutConstraint?
    public var bottomConstraint: NSLayoutConstraint?
    
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
        label.sora.isHidden = true
        label.sora.text = R.string.localizable.selectRecipient(preferredLanguages: .currentLocale)
        return label
    }()
    
    public let accountAddress: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .accentTertiary
        label.sora.font = FontType.textBoldS
        label.sora.numberOfLines = 2
        label.sora.text = R.string.localizable.selectRecipient(preferredLanguages: .currentLocale)
        return label
    }()
    
    private let mainStackView: SoramitsuStackView = {
        var mainStackView = SoramitsuStackView()
        mainStackView.sora.backgroundColor = .custom(uiColor: .clear)
        mainStackView.sora.axis = .vertical
        mainStackView.sora.alignment = .fill
        mainStackView.sora.clipsToBounds = false
        mainStackView.spacing = 4
        return mainStackView
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
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }

    private func setupSubviews() {
        sora.backgroundColor = .bgSurface
        translatesAutoresizingMaskIntoConstraints = false
        mainStackView.addArrangedSubviews(accountTitle, accountAddress)
        addSubview(accountImageView)
        addSubview(mainStackView)
        addSubview(button)
    }

    private func setupConstrains() {
        topConstraint = accountImageView.topAnchor.constraint(equalTo: topAnchor, constant: 18)
        bottomConstraint = accountImageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
        
        NSLayoutConstraint.activate([
            accountImageView.heightAnchor.constraint(equalToConstant: 40),
            accountImageView.widthAnchor.constraint(equalToConstant: 40),
            topConstraint,
            accountImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            bottomConstraint,
            
            mainStackView.leadingAnchor.constraint(equalTo: accountImageView.trailingAnchor, constant: 8),
            mainStackView.centerYAnchor.constraint(equalTo: accountImageView.centerYAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            
            button.topAnchor.constraint(equalTo: topAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }
}
