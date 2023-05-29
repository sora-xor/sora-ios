import SoraUIKit
import Anchorage

final class LanguageItemView: SoramitsuView {
    
    let stack: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.axis = .vertical
        view.sora.distribution = .fillProportionally
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.layoutMargins = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        view.spacing = 8
        return view
    }()
    
    let checkmarkImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.image = R.image.profile.checkmarkGreen()
        return view
    }()

    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.numberOfLines = 1
        label.textAlignment = .left
        label.backgroundColor = .clear
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        return label
    }()
    
    let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.numberOfLines = 1
        label.textAlignment = .left
        label.backgroundColor = .clear
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        return label
    }()
    
    let leftImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    public var isSelectedLanguage: Bool = false {
        didSet {
            checkmarkImageView.sora.isHidden = !isSelectedLanguage
        }
    }
    
    var onTap: (()->())?
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }

    private func setupSubviews() {
        sora.backgroundColor = .custom(uiColor: .clear)
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(checkmarkImageView)
        addSubview(stack)

        stack.addArrangedSubviews(titleLabel)
        stack.addArrangedSubviews(subtitleLabel)
    }

    private func setupConstrains() {
        checkmarkImageView.widthAnchor == 12
        checkmarkImageView.heightAnchor == 12
        checkmarkImageView.leadingAnchor == self.leadingAnchor + 20
        checkmarkImageView.centerYAnchor == self.centerYAnchor
        
        stack.leadingAnchor == checkmarkImageView.trailingAnchor
    }
    
    @objc func didTap() {
        onTap?()
    }
}
