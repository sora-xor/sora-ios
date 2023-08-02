import UIKit
import SoraUIKit
import SnapKit

final class EnabledCell: SoramitsuTableViewCell {
    
    private var enabledItem: EnabledItem?
    
    private lazy var stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.axis = .vertical
        stackView.sora.cornerRadius = .max
        stackView.sora.backgroundColor = .bgSurface
        stackView.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()
    
    private lazy var titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline4
        label.sora.textColor = .fgSecondary
        label.sora.alignment = .left
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupHierarchy()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupHierarchy() {
        contentView.addSubview(stackView)
        stackView.addArrangedSubview(titleLabel)
    }
    
    private func setupLayout() {
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }
    }
}

extension EnabledCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? EnabledItem else {
            assertionFailure("Incorect type of item")
            return
        }
        enabledItem = item
        
        titleLabel.sora.text = item.title
        
//        stackView.arrangedSubviews.filter { $0 is EnabledView }.forEach { subview in
//            stackView.removeArrangedSubview(subview)
//            subview.removeFromSuperview()
//        }
        
        let enabledViews = item.enabledViewModel.map { enabledModel -> EnabledView in
            let enabledView = EnabledView()
            enabledView.titleLabel.sora.text = enabledModel.title
            enabledView.tappableArea.sora.isHidden = false
            enabledView.tappableArea.sora.addHandler(for: .touchUpInside) { [weak enabledItem] in
                enabledItem?.onTap?()
            }
            return enabledView
        }
        
        stackView.addArrangedSubviews(enabledViews)
    }
}

