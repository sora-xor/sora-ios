import SoraUIKit
import FearlessUtils

final class ReceiveCell: SoramitsuTableViewCell {
    
    private var item: ReceiveItem?
    private let generator = PolkadotIconGenerator()
    
    private let contentStackView: SoramitsuStackView = {
        var mainStackView = SoramitsuStackView()
        mainStackView.sora.backgroundColor = .custom(uiColor: .clear)
        mainStackView.sora.axis = .vertical
        mainStackView.sora.distribution = .equalSpacing
        mainStackView.sora.alignment = .fill
        mainStackView.sora.clipsToBounds = false
        mainStackView.spacing = 16
        return mainStackView
    }()
    
    private let qrContainerView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.shadow = .small
        return view
    }()
    
    private let qrImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        return imageView
    }()
    
    private lazy var accountContainerView: SoramitsuControl = {
        var view = SoramitsuControl()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.shadow = .small
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.item?.accountTapHandler?()
        }
        return view
    }()
    
    private let accountImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        imageView.isUserInteractionEnabled = false
        return imageView
    }()
    
    private let mainStackView: SoramitsuStackView = {
        var mainStackView = SoramitsuStackView()
        mainStackView.sora.backgroundColor = .custom(uiColor: .clear)
        mainStackView.sora.axis = .vertical
        mainStackView.sora.distribution = .equalSpacing
        mainStackView.sora.alignment = .fill
        mainStackView.sora.clipsToBounds = false
        mainStackView.spacing = 0
        mainStackView.isUserInteractionEnabled = false
        return mainStackView
    }()
    
    private let accountTitle: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textBoldXS
        label.sora.isHidden = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.isUserInteractionEnabled = false
        return label
    }()
    
    private let accountAddress: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgPrimary
        label.sora.font = FontType.textS
        label.sora.numberOfLines = 2
        label.isUserInteractionEnabled = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()
    
    private let sendAssetView: SendAssetView = SendAssetView()
    
    private lazy var shareButton: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.tintColor = .fgInverted
        button.sora.leftImage = R.image.wallet.send()
        button.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.commonShare(preferredLanguages: .currentLocale),
                                                       fontData: FontType.buttonM,
                                                       textColor: .bgSurface,
                                                       alignment: .center)
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .accentSecondary
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.item?.shareHandler?()
        }
        return button
    }()


    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        qrContainerView.addSubview(qrImageView)
        
        mainStackView.addArrangedSubviews(accountTitle, accountAddress)
        
        accountContainerView.addSubview(accountImageView)
        accountContainerView.addSubviews(mainStackView)
        
        contentView.addSubview(contentStackView)
        contentStackView.addArrangedSubview(qrContainerView)
        contentStackView.addArrangedSubview(accountContainerView)
        contentStackView.addArrangedSubview(sendAssetView)
        contentStackView.addArrangedSubview(shareButton)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            contentStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            qrContainerView.heightAnchor.constraint(equalTo: qrContainerView.widthAnchor),
            
            qrImageView.leadingAnchor.constraint(equalTo: qrContainerView.leadingAnchor, constant: 24),
            qrImageView.centerXAnchor.constraint(equalTo: qrContainerView.centerXAnchor),
            qrImageView.centerYAnchor.constraint(equalTo: qrContainerView.centerYAnchor),
            qrImageView.topAnchor.constraint(equalTo: qrContainerView.topAnchor, constant: 24),

            accountContainerView.heightAnchor.constraint(equalToConstant: 88),
            
            accountImageView.heightAnchor.constraint(equalToConstant: 40),
            accountImageView.widthAnchor.constraint(equalToConstant: 40),
            accountImageView.centerYAnchor.constraint(equalTo: accountContainerView.centerYAnchor),
            accountImageView.leadingAnchor.constraint(equalTo: accountContainerView.leadingAnchor, constant: 16),
            
            mainStackView.leadingAnchor.constraint(equalTo: accountImageView.trailingAnchor, constant: 8),
            mainStackView.trailingAnchor.constraint(equalTo: accountContainerView.trailingAnchor, constant: -16),
            mainStackView.topAnchor.constraint(greaterThanOrEqualTo: accountContainerView.topAnchor, constant: 8),
            mainStackView.centerYAnchor.constraint(equalTo: accountContainerView.centerYAnchor),

            shareButton.heightAnchor.constraint(equalToConstant: 56),
        ])
    }
}

extension ReceiveCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? ReceiveItem else {
            assertionFailure("Incorect type of item")
            return
        }
        self.item = item
        accountAddress.sora.text = item.address
        accountImageView.image = try? generator.generateFromAddress(item.address)
            .imageWithFillColor(.white,
                                size: CGSize(width: 40.0, height: 40.0),
                                contentScale: UIScreen.main.scale)
        
        qrImageView.image = item.qrImage
        accountTitle.sora.text = item.name
        accountTitle.sora.isHidden = item.name.isEmpty
        sendAssetView.sora.isHidden = item.sendAssetViewModel == nil
        sendAssetView.setupView(with: item.sendAssetViewModel)
    }
}

