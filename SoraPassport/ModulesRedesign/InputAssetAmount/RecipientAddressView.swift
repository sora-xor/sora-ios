import SoraUIKit
import Anchorage

final class RecipientAddressView: SoramitsuView {

    public let titleLabel: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.headline4
        label.sora.text = R.string.localizable.recipientAddress(preferredLanguages: .currentLocale).uppercased()
        return label
    }()
    
    public let contactView: ContactView = {
        let view = ContactView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.button.sora.isHidden = false
        return view
    }()
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }

    private func setupSubviews() {
        sora.shadow = .small
        sora.cornerRadius = .max
        sora.backgroundColor = .bgSurface
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        addSubview(contactView)
    }

    private func setupConstrains() {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            contactView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            contactView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contactView.centerXAnchor.constraint(equalTo: centerXAnchor),
            contactView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])
    }
}
