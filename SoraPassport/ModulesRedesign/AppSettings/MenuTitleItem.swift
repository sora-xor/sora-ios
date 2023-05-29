import SoraUIKit
import Anchorage

class MenuTitleItem: SoramitsuView {

    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.numberOfLines = 1
        label.textAlignment = .left
        label.backgroundColor = .clear
        label.sora.font = FontType.headline4
        label.sora.textColor = .fgSecondary
        return label
    }()

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }

    private func setupSubviews() {

        translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
    }

    private func setupConstrains() {
        titleLabel.leftAnchor == leftAnchor + 24
        titleLabel.rightAnchor == rightAnchor + 24
        titleLabel.topAnchor == topAnchor + 24
        titleLabel.bottomAnchor == bottomAnchor
    }
}
