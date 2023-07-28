import Foundation
import SoraUIKit
import Combine

public final class ExploreAssetView: SoramitsuView {
    
    // MARK: - UI
    
    public let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 0
        stackView.isUserInteractionEnabled = false
        return stackView
    }()
    
    public let serialNumber: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.widthAnchor.constraint(equalToConstant: 24).isActive = true
        return label
    }()
    
    public let assetImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 40).isActive = true
        view.widthAnchor.constraint(equalToConstant: 40).isActive = true
        view.isUserInteractionEnabled = false
        view.sora.loadingPlaceholder.type = .shimmer
        view.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        return view
    }()
    
    public let infoStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.isUserInteractionEnabled = false
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    public let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        label.sora.isUserInteractionEnabled = false
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
        return label
    }()
    
    public let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.isUserInteractionEnabled = false
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
        return label
    }()
    
    public let amountStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 4
        stackView.isUserInteractionEnabled = false
        stackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return stackView
    }()
    
    public let amountUpLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .right
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
        return label
    }()
    
    public let amountDownLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .statusSuccess
        label.sora.alignment = .right
        label.sora.text = " "
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    public let tappableArea: SoramitsuControl = {
        let view = SoramitsuControl()
        view.sora.isHidden = true
        return view
    }()
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension ExploreAssetView {
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        addSubview(tappableArea)
        
        infoStackView.addArrangedSubview(titleLabel)
        infoStackView.addArrangedSubview(subtitleLabel)
        
        amountStackView.addArrangedSubview(amountUpLabel)
        amountStackView.addArrangedSubview(amountDownLabel)
        
        stackView.addArrangedSubview(serialNumber)
        stackView.addArrangedSubview(assetImageView)
        stackView.setCustomSpacing(8, after: assetImageView)
        stackView.addArrangedSubview(infoStackView)
        stackView.setCustomSpacing(8, after: infoStackView)
        stackView.addArrangedSubview(amountStackView)

        NSLayoutConstraint.activate([
            tappableArea.leadingAnchor.constraint(equalTo: leadingAnchor),
            tappableArea.topAnchor.constraint(equalTo: topAnchor),
            tappableArea.centerXAnchor.constraint(equalTo: centerXAnchor),
            tappableArea.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 40),
        ])
    }
}
