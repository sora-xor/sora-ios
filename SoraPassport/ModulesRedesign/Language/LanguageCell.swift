import SoraUIKit
import Anchorage

final class LanguageCell: SoramitsuTableViewCell {
    
    let itemView: LanguageItemView = {
        let view = LanguageItemView(frame: .zero)
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
    
    private func setupView() {
        sora.clipsToBounds = true
        contentView.addSubview(itemView)
    }
    
    func setupConstraints() {
        itemView.leftAnchor == contentView.leftAnchor + 16
        itemView.rightAnchor == contentView.rightAnchor - 16
        itemView.topAnchor == contentView.topAnchor
        itemView.bottomAnchor == contentView.bottomAnchor
    }
}

extension LanguageCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? LanguageItem else {
            return
        }
        
        itemView.titleLabel.sora.text = item.title
        itemView.subtitleLabel.sora.text = item.subtitle
        itemView.isSelectedLanguage = item.selected
        itemView.onTap = item.onTap
    }
}
