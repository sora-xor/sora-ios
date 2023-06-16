import SoraUIKit
import Anchorage
import FearlessUtils

final class AccountImportedCell: SoramitsuTableViewCell {
    private var item: AccountImportedItem?
    private let generator = PolkadotIconGenerator()

    private let contentTitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.alignment = .center
        label.sora.text = R.string.localizable.succesfullyImportedAccountTitle(preferredLanguages: .currentLocale)
        return label
    }()
    
    private let accountView: AccountView = {
        let view = AccountView()
        view.sora.backgroundColor = .bgPage
        return view
    }()
    
    private let stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.alignment = .fill
        stackView.sora.axis = .vertical
        stackView.sora.distribution = .fill
        stackView.spacing = 16
        return stackView
    }()
    
    private lazy var continueButton: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.title = R.string.localizable.transactionContinue(preferredLanguages: .currentLocale)
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .accentPrimary
        button.sora.horizontalOffset = 0
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.item?.continueTapHandler?()
        }
        return button
    }()
    
    private lazy var importAccountButton: SoramitsuButton = {
        let title = SoramitsuTextItem(text: R.string.localizable.importMoreTitle(preferredLanguages: .currentLocale),
                                      fontData: FontType.buttonM,
                                      textColor: .accentPrimary,
                                      alignment: .center)
        
        let button = SoramitsuButton()
        button.sora.horizontalOffset = 0
        button.sora.cornerRadius = .circle
        button.sora.backgroundColor = .custom(uiColor: .clear)
        button.sora.attributedText = title
        button.sora.borderColor = .accentPrimary
        button.sora.borderWidth = 1
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.item?.loadMoreTapHandler?()
        }
        return button
    }()
    
    private let containerView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
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
        contentView.addSubview(containerView)
        stackView.addArrangedSubviews([continueButton, importAccountButton])
        containerView.addSubviews([contentTitleLabel, accountView, stackView])
    }
    
    func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            contentTitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            contentTitleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            contentTitleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            
            accountView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            accountView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            accountView.topAnchor.constraint(equalTo: contentTitleLabel.bottomAnchor, constant: 32),
            
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            stackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            stackView.topAnchor.constraint(equalTo: accountView.bottomAnchor, constant: 24),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32),
        ])
    }
}

extension AccountImportedCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? AccountImportedItem else {
            return
        }
        importAccountButton.sora.isHidden = !item.areThereAnotherAccounts
        accountView.accountTitle.sora.text = item.accountName
        accountView.accountTitle.sora.isHidden = item.accountName?.isEmpty ?? true
        accountView.accountAddress.sora.text = item.accountAddress
        accountView.accountImageView.image = try? generator.generateFromAddress(item.accountAddress)
            .imageWithFillColor(.white,
                                size: CGSize(width: 40.0, height: 40.0),
                                contentScale: UIScreen.main.scale)
        self.item = item
    }
}
