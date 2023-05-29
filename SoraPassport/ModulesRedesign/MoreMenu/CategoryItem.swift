import SoraUIKit
import Anchorage

class CategoryItem: SoramitsuView {

    let horizontalStack: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .horizontal
        view.layer.cornerRadius = 32
        view.sora.distribution = .fillProportionally
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    let verticalStack: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.spacing = 4
        view.sora.distribution = .fill
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    let subtitleView: SoramitsuView = {
        var view = SoramitsuView(frame: .zero)
        view.sora.backgroundColor = .bgSurface
        return view
    }()

    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.numberOfLines = 1
        label.textAlignment = .left
        label.backgroundColor = .clear
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        return label
    }()

    let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.textAlignment = .left
        label.backgroundColor = .clear
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }()

    let circle: SoramitsuView = {
        let view = SoramitsuView(frame: .zero)
        view.sora.cornerRadius = .circle
        view.sora.clipsToBounds = true
        return view
    }()

    let rightImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstraints()
    }

    private func setupSubviews() {

        translatesAutoresizingMaskIntoConstraints = false

        addSubview(horizontalStack)

        subtitleView.addSubview(subtitleLabel)

        verticalStack.addArrangedSubviews(titleLabel)
        verticalStack.addArrangedSubviews(subtitleView)

        horizontalStack.addArrangedSubviews(verticalStack)
        horizontalStack.addArrangedSubviews(rightImageView)
    }

    private func setupConstraints() {
        rightImageView.widthAnchor == 24
        subtitleView.heightAnchor == 14
        horizontalStack.edgeAnchors == edgeAnchors
    }

    func addCircle() {
        subtitleView.addSubview(circle)
        circle.heightAnchor == 8
        circle.widthAnchor == 8
        circle.topAnchor == subtitleView.topAnchor + 3
        subtitleLabel.leadingAnchor == circle.trailingAnchor + 4
    }
}
