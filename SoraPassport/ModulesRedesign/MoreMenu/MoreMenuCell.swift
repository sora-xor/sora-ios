import SoraUIKit
import Anchorage

final class MoreMenuCell: SoramitsuTableViewCell {

    let categoryItem: CategoryItem = {
        let view = CategoryItem(frame: .zero)
        view.sora.shadow = .default
        view.sora.cornerRadius = .max
        view.sora.clipsToBounds = true
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupView() {
        contentView.addSubview(categoryItem)
    }

    func setupConstraints() {
        categoryItem.leadingAnchor == contentView.leadingAnchor + 16
        categoryItem.trailingAnchor == contentView.trailingAnchor - 16
        categoryItem.topAnchor == contentView.topAnchor + 8
        categoryItem.bottomAnchor == contentView.bottomAnchor - 8
    }
}

extension MoreMenuCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? MoreMenuItem else {
            return
        }

        categoryItem.titleLabel.sora.text = item.title
        categoryItem.subtitleLabel.sora.text = item.subtitle
        categoryItem.rightImageView.sora.picture = item.picture

        if let circleColor = item.circleColor {
            categoryItem.addCircle()
            categoryItem.circle.sora.backgroundColor = circleColor
        }
    }
}

