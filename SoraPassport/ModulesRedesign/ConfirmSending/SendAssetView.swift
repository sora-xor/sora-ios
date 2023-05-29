import SoraUIKit
import FearlessUtils

struct SendAssetViewModel {
    let symbol: String
    let amount: String?
    let balance: String?
    let fiat: String?
    let svgString: String?
}

final class SendAssetView: SoramitsuView {
    
    private let containerView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.shadow = .small
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        return view
    }()
    
    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.headline4
        label.sora.text = R.string.localizable.sendAsset(preferredLanguages: .currentLocale).uppercased()
        return label
    }()
    
    let assetImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        return imageView
    }()
    
    let symbolLabel: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgPrimary
        label.sora.font = FontType.displayS
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    let amountLabel: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgPrimary
        label.sora.font = FontType.displayS
        return label
    }()
    
    let balanceLabel: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textBoldXS
        return label
    }()
    
    let fiatLabel: SoramitsuLabel = {
        var label = SoramitsuLabel()
        label.sora.textColor = .fgSecondary
        label.sora.font = FontType.textBoldXS
        label.sora.alignment = .right
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupView()
        setupConstraints()
    }
    
    private func setupView() {
        sora.clipsToBounds = false
        sora.backgroundColor = .custom(uiColor: .clear)
        addSubviews(containerView)
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(assetImageView)
        containerView.addSubview(symbolLabel)
        containerView.addSubview(amountLabel)
        containerView.addSubview(balanceLabel)
        containerView.addSubview(fiatLabel)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            
            assetImageView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            assetImageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            assetImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32),
            assetImageView.widthAnchor.constraint(equalToConstant: 40),
            assetImageView.heightAnchor.constraint(equalToConstant: 40),
            
            symbolLabel.leadingAnchor.constraint(equalTo: assetImageView.trailingAnchor, constant: 8),
            symbolLabel.topAnchor.constraint(equalTo: assetImageView.topAnchor),
            
            balanceLabel.leadingAnchor.constraint(equalTo: assetImageView.trailingAnchor, constant: 8),
            balanceLabel.bottomAnchor.constraint(equalTo: assetImageView.bottomAnchor),
            
            amountLabel.leadingAnchor.constraint(equalTo: symbolLabel.trailingAnchor, constant: 8),
            amountLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            amountLabel.topAnchor.constraint(equalTo: assetImageView.topAnchor),
            
            fiatLabel.leadingAnchor.constraint(equalTo: balanceLabel.trailingAnchor, constant: 8),
            fiatLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            fiatLabel.bottomAnchor.constraint(equalTo: assetImageView.bottomAnchor),
            
        ])
    }
}

extension SendAssetView {
    func setupView(with viewModel: SendAssetViewModel?) {
        guard let viewModel = viewModel else { return }
        assetImageView.image = RemoteSerializer.shared.image(with: viewModel.svgString ?? "")
        symbolLabel.sora.text = viewModel.symbol
        balanceLabel.sora.text = viewModel.balance
        amountLabel.sora.text = viewModel.amount
        fiatLabel.sora.text = viewModel.fiat
    }
}
