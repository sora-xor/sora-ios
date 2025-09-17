import Foundation
import UIKit

public final class PoolView: UIControl, Molecule {
    
    public let sora: PoolViewConfiguration<PoolView>
    public var isRightToLeft: Bool = false {
        didSet {
            setupSemantics()
        }
    }
    
    // MARK: - UI
    
    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 0
        stackView.isUserInteractionEnabled = false
        return stackView
    }()
    
    public let favoriteButton: ImageButton = {
        let view = ImageButton(size: CGSize(width: 40, height: 40))
        view.isHidden = true
        return view
    }()
    
    let currenciesView: SoramitsuView = {
        let view = SoramitsuView()
        view.heightAnchor.constraint(equalToConstant: 40).isActive = true
        view.widthAnchor.constraint(equalToConstant: 64).isActive = true
        view.sora.isUserInteractionEnabled = false
        return view
    }()
    
    public let firstCurrencyImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 40).isActive = true
        view.widthAnchor.constraint(equalToConstant: 40).isActive = true
        view.isUserInteractionEnabled = false
        view.sora.loadingPlaceholder.type = .shimmer
        view.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        return view
    }()
    
    public let secondCurrencyImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 40).isActive = true
        view.widthAnchor.constraint(equalToConstant: 40).isActive = true
        view.isUserInteractionEnabled = false
        view.sora.loadingPlaceholder.type = .shimmer
        view.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        return view
    }()
    
    let rewardViewContainter: SoramitsuView = {
        let view = SoramitsuView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgPage
        view.sora.cornerRadius = .circle
        view.sora.isUserInteractionEnabled = false
        view.heightAnchor.constraint(equalToConstant: 22).isActive = true
        view.widthAnchor.constraint(equalToConstant: 22).isActive = true
        return view
    }()
    
    public let rewardImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 18).isActive = true
        view.widthAnchor.constraint(equalToConstant: 18).isActive = true
        view.sora.cornerRadius = .circle
        view.sora.borderColor = .bgPage
        view.sora.isUserInteractionEnabled = false
        view.sora.backgroundColor = .additionalPolkaswap
        view.sora.loadingPlaceholder.type = .shimmer
        view.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .circle
        return view
    }()
    
    let infoStackView: UIStackView = {
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
        label.sora.isHidden = true
        label.sora.isUserInteractionEnabled = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
        return label
    }()
    
    let amountStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 4
        stackView.isUserInteractionEnabled = false
        stackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return stackView
    }()
    
    public let amountUpLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .right
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.sora.loadingPlaceholder.type = .shimmer
        label.sora.loadingPlaceholder.shimmerview.sora.cornerRadius = .small
        return label
    }()
    
    public let amountDownView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        return view
    }()
    
    public let amountDownLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .statusSuccess
        label.sora.alignment = .right
        label.sora.text = " "
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    init(style: SoramitsuStyle, mode: WalletViewMode = .view) {
        sora = PoolViewConfiguration(style: style, mode: mode)
        super.init(frame: .zero)
        sora.owner = self
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension PoolView {
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        
        currenciesView.addSubview(firstCurrencyImageView)
        rewardViewContainter.addSubviews(rewardImageView)
        
        currenciesView.addSubview(secondCurrencyImageView)
        currenciesView.addSubview(rewardViewContainter)
        
        infoStackView.addArrangedSubview(titleLabel)
        infoStackView.addArrangedSubview(subtitleLabel)
        
        amountStackView.addArrangedSubview(amountUpLabel)
        amountStackView.addArrangedSubview(amountDownView)
        
        amountDownView.addSubview(amountDownLabel)
        
        stackView.addArrangedSubview(favoriteButton)
        stackView.setCustomSpacing(16, after: favoriteButton)
        stackView.addArrangedSubview(currenciesView)
        stackView.setCustomSpacing(8, after: currenciesView)
        stackView.addArrangedSubview(infoStackView)
        stackView.setCustomSpacing(8, after: infoStackView)
        stackView.addArrangedSubview(amountStackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 40),
            
            firstCurrencyImageView.leadingAnchor.constraint(equalTo: currenciesView.leadingAnchor),
            firstCurrencyImageView.centerYAnchor.constraint(equalTo: currenciesView.centerYAnchor),
            firstCurrencyImageView.topAnchor.constraint(equalTo: currenciesView.topAnchor),
            secondCurrencyImageView.leadingAnchor.constraint(equalTo: firstCurrencyImageView.leadingAnchor, constant: 24),
            secondCurrencyImageView.trailingAnchor.constraint(equalTo: currenciesView.trailingAnchor),
            rewardImageView.trailingAnchor.constraint(equalTo: secondCurrencyImageView.trailingAnchor),
            rewardImageView.bottomAnchor.constraint(equalTo: secondCurrencyImageView.bottomAnchor),

            rewardViewContainter.centerXAnchor.constraint(equalTo: rewardImageView.centerXAnchor),
            rewardViewContainter.centerYAnchor.constraint(equalTo: rewardImageView.centerYAnchor),
            
            amountDownLabel.trailingAnchor.constraint(equalTo: amountDownView.trailingAnchor)
        ])
    }
    
    private func setupSemantics() {
        let alignment: NSTextAlignment = isRightToLeft ? .right : .left
        let reversedAlignment: NSTextAlignment = isRightToLeft ? .left : .right
        titleLabel.sora.alignment = alignment
        subtitleLabel.sora.alignment = alignment
        amountUpLabel.sora.alignment = reversedAlignment
        amountDownLabel.sora.alignment = reversedAlignment
    }
}

public extension PoolView {
    
    convenience init(mode: WalletViewMode = .view) {
        let sora = SoramitsuUI.shared
        self.init(style: sora.style, mode: mode)
    }
}
