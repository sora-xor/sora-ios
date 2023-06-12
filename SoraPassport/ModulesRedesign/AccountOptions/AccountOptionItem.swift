import SoraUIKit
import Anchorage

class AccountOptionItem: SoramitsuView {

    let horizontalStack: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .horizontal
        view.sora.cornerRadius = .max
        view.sora.distribution = .fillProportionally
        view.layoutMargins = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        view.spacing = 8
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

    var onTap: (()->())?

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
        setupGestureRecognizer()
    }

    private func setupSubviews() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(horizontalStack)

        horizontalStack.addArrangedSubviews(leftImageView)
        horizontalStack.addArrangedSubviews(titleLabel)
    }

    private func setupConstrains() {
        leftImageView.widthAnchor == 24
        arrow.widthAnchor == 24
        titleLabel.heightAnchor == 24
        horizontalStack.edgeAnchors == edgeAnchors
    }

    func addArrow() {
        horizontalStack.insertArrangedSubview(arrow, at: 2)
    }

    func setupGestureRecognizer() {
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tapGR)
    }

    @objc func didTap() {
        onTap?()
    }
}
