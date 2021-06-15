import Foundation
import SoraUI

class TitleWithAccessoryView: UIView {
    private(set) var titleView: ImageWithTitleView!
    private(set) var accessoryLabel: UILabel!

    override var intrinsicContentSize: CGSize {
        let height = max(titleView.intrinsicContentSize.height,
                         accessoryLabel.intrinsicContentSize.height)
        let width = titleView.intrinsicContentSize.width + accessoryLabel.intrinsicContentSize.width
        return CGSize(width: width, height: height)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    func invalidateLayout() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func configure() {
        backgroundColor = .clear

        titleView = ImageWithTitleView()
        titleView.translatesAutoresizingMaskIntoConstraints = false
        titleView.layoutType = .horizontalImageFirst
        addSubview(titleView)

        accessoryLabel = UILabel()
        accessoryLabel.translatesAutoresizingMaskIntoConstraints = false
        accessoryLabel.textAlignment = .right
        addSubview(accessoryLabel)

        titleView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        titleView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        accessoryLabel.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        accessoryLabel.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        titleView.trailingAnchor.constraint(equalTo: accessoryLabel.leadingAnchor).isActive = true

        titleView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        accessoryLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        titleView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        accessoryLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
}
