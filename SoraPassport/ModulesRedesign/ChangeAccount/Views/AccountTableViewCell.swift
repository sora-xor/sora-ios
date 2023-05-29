import SoraUIKit
import Anchorage

final class AccountTableViewCell: SoramitsuTableViewCell {

    // MARK: - Outlets
    private lazy var itemView: AccountMenuItemView = {
        AccountMenuItemView(frame: .zero)
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        sora.clipsToBounds = true
        contentView.addSubview(itemView)
    }
    
    func setupConstraints() {
        itemView.leftAnchor == contentView.leftAnchor + 24
        itemView.rightAnchor == contentView.rightAnchor - 24
        itemView.topAnchor == contentView.topAnchor
        itemView.bottomAnchor == contentView.bottomAnchor
    }
}

extension AccountTableViewCell: SoramitsuTableViewCellProtocol {

    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? AccountMenuItem else {
            return
        }
        
        itemView.bind(model: item)
        itemView.addTapGesture(with: { recognizer in
            item.onTap?()
        })
    }
    
}
