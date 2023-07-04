import SoraUIKit
import SnapKit

final class FriendsCell: SoramitsuTableViewCell {
    
    private var friendsItem: FriendsItem?
    
    private lazy var containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.clipsToBounds = false
        return view
    }()
    
    private lazy var titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.settingsInviteTitle(preferredLanguages: .currentLocale)
        label.sora.textColor = .fgPrimary
        label.sora.font = FontType.headline2
        label.numberOfLines = 2
        return label
    }()
    
    private lazy var descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = R.string.localizable.referralTitle(preferredLanguages: .currentLocale)
        label.sora.textColor = .fgPrimary
        label.sora.font = FontType.paragraphXS
        label.numberOfLines = 2
        return label
    }()
    
    private lazy var pictureView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.image = R.image.archerGirl()
        imageView.sora.contentMode = .scaleAspectFill
        return imageView
    }()
    
    private lazy var startInvitingButton: SoramitsuButton = {
        let title = SoramitsuTextItem(text: R.string.localizable.referralStartInviting(preferredLanguages: .currentLocale) ,
                                      fontData: FontType.textBoldS ,
                                      textColor: .bgSurface,
                                      alignment: .center)
        
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .accentPrimary
        button.sora.attributedText = title
        button.sora.isUserInteractionEnabled = false
        return button
    }()
    
    private lazy var closeButton: ImageButton = {
        let button = ImageButton(size: CGSize(width: 24, height: 24))
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .custom(uiColor: .clear)
        button.sora.image = R.image.roundClose()
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.friendsItem?.onClose?()
        }
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
        contentView.addSubview(containerView)
        contentView.addSubview(closeButton)

        containerView.addSubviews([titleLabel, descriptionLabel, startInvitingButton, pictureView])
    }
    
    private func setupLayout() {
        
        containerView.snp.makeConstraints { make in
            make.top.equalTo(contentView).offset(8)
            make.leading.equalTo(contentView).offset(16)
            make.center.equalTo(contentView)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(containerView).offset(16)
            make.leading.equalTo(containerView).offset(24)
            make.width.equalTo(124)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.equalTo(containerView).offset(24)
            make.width.equalTo(151)
        }
        
        startInvitingButton.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(12)
            make.leading.equalTo(containerView).offset(24)
            make.width.equalTo(107)
            make.height.equalTo(32)
        }
        
        pictureView.snp.makeConstraints { make in
            make.top.trailing.bottom.equalTo(containerView)
            make.width.equalTo(136)
            make.height.equalTo(164)
        }
        
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(contentView).offset(24)
            make.trailing.equalTo(contentView).offset(-32)
        }
    }
}

extension FriendsCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? FriendsItem else {
            assertionFailure("Incorect type of item")
            return
        }
        friendsItem = item
    }
}
