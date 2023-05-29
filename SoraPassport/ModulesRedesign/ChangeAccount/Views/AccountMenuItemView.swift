import Foundation
import SoraUIKit
import Anchorage

final class AccountMenuItemView: SoramitsuView {
    private let titleLabel: SoramitsuLabel = {
        SoramitsuLabel().then {
            $0.sora.font = FontType.textM
            $0.sora.textColor = .fgPrimary
            $0.sora.backgroundColor = .custom(uiColor: .clear)
            $0.numberOfLines = 1
            $0.lineBreakMode = .byTruncatingTail
        }
    }()

    private let checkmarkView: UIImageView = {
        UIImageView().then {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    private let iconView: UIImageView = {
        UIImageView().then {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    private var moreButton: UIButton = {
        UIButton() .then {
            $0.setImage(R.image.iconMenuInfo(), for: .normal)
            $0.addTarget(self, action: #selector(onMoreTap), for: .touchUpInside)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    private var model: AccountMenuItem?

    override init(frame: CGRect) {
        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkmarkView)
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(moreButton)

        checkmarkView.do {
            $0.centerYAnchor == centerYAnchor
            $0.leadingAnchor == leadingAnchor
            $0.widthAnchor == 14
            $0.heightAnchor == 10
        }

        iconView.do {
            $0.centerYAnchor == centerYAnchor
            $0.leadingAnchor == checkmarkView.trailingAnchor + 21
            $0.sizeAnchors == CGSize(width: 40, height: 40)
            $0.topAnchor == topAnchor + 16
            $0.bottomAnchor == bottomAnchor - 16
        }

        titleLabel.do {
            $0.leadingAnchor == iconView.trailingAnchor + 8
            $0.trailingAnchor == moreButton.leadingAnchor - 8
            $0.centerYAnchor == centerYAnchor
        }

        moreButton.do {
            $0.centerYAnchor == centerYAnchor
            $0.trailingAnchor == trailingAnchor - 4
            $0.sizeAnchors == CGSize(width: 24, height: 24)
        }
        
        sora.backgroundColor = .custom(uiColor: .clear)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(model: AccountMenuItem) {
        titleLabel.sora.text = model.title
        checkmarkView.image = model.isSelected ? R.image.listCheckmarkIcon() : nil
        if let image = model.image {
            iconView.image = image
            iconView.isHidden = false
            iconView.widthAnchor == 40
        } else {
            iconView.isHidden = true
            iconView.widthAnchor == 0
        }
        self.model = model
    }


    @objc
    func onMoreTap() {
        if let model = self.model,
           let more = model.onMore {
            more()
        }
    }
}
