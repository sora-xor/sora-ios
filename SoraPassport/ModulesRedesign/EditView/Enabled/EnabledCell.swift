import UIKit
import SoraUIKit
import SnapKit

final class EnabledCell: SoramitsuTableViewCell {
    
    private var enabledItem: EnabledItem?
    
    private lazy var editButton: SoramitsuButton = {
        let title = SoramitsuTextItem(text: R.string.localizable.editView(preferredLanguages: .currentLocale),
                                      fontData: FontType.buttonM ,
                                      textColor: .accentSecondary,
                                      alignment: .center)
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .bgSurface
        button.sora.attributedText = title
        button.sora.isUserInteractionEnabled = false
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return button
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupHierarchy()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupHierarchy() {
        contentView.addSubview(editButton)
    }
    
    private func setupLayout() {
        editButton.snp.makeConstraints { make in
            make.top.equalTo(contentView).offset(8)
            make.center.equalTo(contentView)
            make.height.equalTo(40)
            make.width.equalTo(108)
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
    }
}

