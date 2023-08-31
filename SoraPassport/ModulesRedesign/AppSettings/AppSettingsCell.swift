import SoraUIKit
import Anchorage

class AppSettingsCell: SoramitsuTableViewCell {

    let menuItem: MenuItem = {
        let view = MenuItem(frame: .zero)
        view.sora.shadow = .default
        view.sora.cornerRadius = .max
        view.sora.clipsToBounds = true
        view.sora.backgroundColor = .custom(uiColor: .clear)
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
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.addSubview(menuItem)
    }

    func setupConstraints() {
        menuItem.leadingAnchor == contentView.leadingAnchor + 16
        menuItem.trailingAnchor == contentView.trailingAnchor - 16
        menuItem.topAnchor == contentView.topAnchor + 8
        menuItem.bottomAnchor == contentView.bottomAnchor - 8
    }
}

extension AppSettingsCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? AppSettingsItem else {
            return
        }

        menuItem.titleLabel.sora.text = item.title
        menuItem.leftImageView.sora.picture = item.picture

        switch item.rightItem {
        case .arrow:
            menuItem.addArrow()
        case .switcher(let state):
            menuItem.addSwitcher()
            menuItem.switcher.isEnabled = state != .disabled
            menuItem.switcher.isOn = state == .on
        }
        menuItem.onTap = item.onTap
        menuItem.onSwitch = item.onSwitch
    }
}

