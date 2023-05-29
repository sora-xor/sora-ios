import SoraUIKit
import Anchorage

class InformationItemView: SoramitsuView {

    let horizontalStack: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .horizontal
        view.sora.cornerRadius = .max
        view.sora.cornerMask = .none
        view.sora.distribution = .fillProportionally
        view.layoutMargins = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        view.spacing = 16
        return view
    }()
    
    let labelStack: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.distribution = .fillProportionally
        view.layoutMargins = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        view.isLayoutMarginsRelativeArrangement = false
        view.spacing = 4
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
    
    lazy var separator: UIView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .fgOutline
        return view
    }()

    let leftImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    let arrow: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.image = R.image.iconSmallArrow()!
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    let link: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.image = R.image.arrowTopRight()!
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    var onTap: (()->())?

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstraints()
        setupGestureRecognizer()
    }

    private func setupSubviews() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        
        labelStack.addArrangedSubview(titleLabel)

        addSubview(horizontalStack)

        horizontalStack.addArrangedSubviews(leftImageView)
        horizontalStack.addArrangedSubviews(labelStack)
    }

    private func setupConstraints() {
        leftImageView.widthAnchor == 24
        arrow.widthAnchor == 24
        link.widthAnchor == 24
        horizontalStack.edgeAnchors == edgeAnchors
    }
    
    func set(subtitle: String) {
        labelStack.layoutMargins = UIEdgeInsets(top: 4, left: 24, bottom: 4, right: 24)
        labelStack.addArrangedSubview(subtitleLabel)
        subtitleLabel.sora.text = subtitle
    }

    func addArrow() {
        horizontalStack.insertArrangedSubview(arrow, at: 2)
    }

    func addLink() {
        horizontalStack.insertArrangedSubview(link, at: 2)
    }
    
    func addSeparator() {
        addSubview(separator)
        separator.leadingAnchor == labelStack.leadingAnchor
        separator.heightAnchor == 1
        separator.bottomAnchor == self.bottomAnchor
        separator.trailingAnchor == self.trailingAnchor
    }

    func setupGestureRecognizer() {
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tapGR)
    }

    @objc func didTap() {
        onTap?()
    }
}
