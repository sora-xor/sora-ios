import SoraUIKit
import Anchorage

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
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }

    private func setupSubviews() {
        sora.backgroundColor = .bgSurface
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(accountImageView)
        addSubview(accountTitle)
        addSubview(arrowImageView)
        addSubview(button)
    }

    private func setupConstrains() {
        NSLayoutConstraint.activate([
            accountImageView.heightAnchor.constraint(equalToConstant: 40),
            accountImageView.widthAnchor.constraint(equalToConstant: 40),
            accountImageView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            accountImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            accountImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            accountTitle.leadingAnchor.constraint(equalTo: accountImageView.trailingAnchor, constant: 8),
            accountTitle.centerYAnchor.constraint(equalTo: accountImageView.centerYAnchor),
            accountTitle.trailingAnchor.constraint(equalTo: arrowImageView.leadingAnchor, constant: -8),
            
            arrowImageView.heightAnchor.constraint(equalToConstant: 24),
            arrowImageView.widthAnchor.constraint(equalToConstant: 24),
            arrowImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            arrowImageView.centerYAnchor.constraint(equalTo: accountImageView.centerYAnchor),
            
            button.topAnchor.constraint(equalTo: topAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }
}
