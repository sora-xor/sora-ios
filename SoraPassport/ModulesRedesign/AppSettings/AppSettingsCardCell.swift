import SoraUIKit
import Anchorage

class AppSettingsCardCell: SoramitsuTableViewCell {

    let containerView: SoramitsuView = {
        let container = SoramitsuView()
        container.sora.backgroundColor = .bgSurface
        container.sora.cornerRadius = .max
        container.sora.clipsToBounds = true
        container.sora.shadow = .default
        return container
    }()

    let stack: SoramitsuStackView = {
        let view = SoramitsuStackView()
        view.sora.axis = .vertical
        view.sora.cornerRadius = .max
        view.sora.clipsToBounds = true
        view.sora.distribution = .fill

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
        containerView.addSubview(stack)
        contentView.addSubview(containerView)
    }

    func setupConstraints() {
        containerView.leftAnchor == contentView.leftAnchor + 16
        containerView.rightAnchor == contentView.rightAnchor - 16
        containerView.topAnchor == contentView.topAnchor + 8
        containerView.bottomAnchor == contentView.bottomAnchor - 8

        stack.edgeAnchors == containerView.edgeAnchors
    }
}

extension AppSettingsCardCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? AppSettingsCardItem else {
            return
        }
        
        stack.removeArrangedSubviews()

        if let title = item.title {
            let titleView = self.titleView(for: title)
            stack.addArrangedSubviews(titleView)
        }

        for appSettingsItem in item.menuItems {
            let subview = self.menuItemView(from: appSettingsItem)
            stack.addArrangedSubviews(subview)
        }
    }

    private func titleView(for title: String) -> MenuTitleItem {
        let view = MenuTitleItem(frame: .zero)
        view.titleLabel.sora.text = title
        return view
    }

    private func menuItemView(from item: AppSettingsItem) -> MenuItem {
        let view = MenuItem(frame: .zero)
        view.horizontalStack.layer.cornerRadius = 0
        view.sora.shadow = .none
        view.sora.clipsToBounds = false

        view.titleLabel.sora.text = item.title
        view.leftImageView.sora.picture = item.picture
        view.leftImageView.isHidden = item.picture == nil

        switch item.rightItem {
        case .arrow:
            view.addArrow()
        case .switcher(let state):
            view.addSwitcher()
            view.switcher.isEnabled = state != .disabled
            view.switcher.isOn = state == .on
        }

        view.onTap = item.onTap
        view.onSwitch = item.onSwitch

        return view
    }

}

