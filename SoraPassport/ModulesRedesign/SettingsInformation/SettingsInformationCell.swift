import SoraUIKit
import Anchorage

final class SettingsInformationCell: SoramitsuTableViewCell {
    
    let informationItem: InformationItemView = {
        let view = InformationItemView(frame: .zero)
        view.horizontalStack.layer.cornerRadius = 0
        view.sora.shadow = .none
        view.sora.clipsToBounds = false
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
        contentView.addSubview(informationItem)
    }

    func setupConstraints() {
        informationItem.leftAnchor == contentView.leftAnchor + 16
        informationItem.rightAnchor == contentView.rightAnchor - 16
        informationItem.topAnchor == contentView.topAnchor
        informationItem.bottomAnchor == contentView.bottomAnchor
    }
}

extension SettingsInformationCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? InformationItem else {
            return
        }

        informationItem.titleLabel.sora.text = item.title
        
        if let subtitle = item.subtitle {
            informationItem.set(subtitle: subtitle)
        }
        
        informationItem.leftImageView.sora.picture = item.picture
        informationItem.leftImageView.isHidden = item.picture == nil

        switch item.rightItem {
        case .arrow:
            informationItem.addArrow()
        case .link:
            informationItem.addLink()
        }
        
        switch item.position {
        case .first:
            informationItem.addSeparator()
            informationItem.horizontalStack.sora.cornerMask = .top

        case .last:
            informationItem.horizontalStack.sora.cornerMask = .bottom
    
        default:
            informationItem.horizontalStack.sora.cornerMask = .none
            informationItem.addSeparator()
        }

        informationItem.onTap = item.onTap
    }
}

