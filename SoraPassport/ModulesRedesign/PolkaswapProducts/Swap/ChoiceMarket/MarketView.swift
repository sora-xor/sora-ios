import Foundation
import SoraUIKit
import UIKit

final class MarketView: SoramitsuControl {

    let checkmarkImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.image = R.image.wallet.checkmark()
        return view
    }()
    
    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    let infoButton: ImageButton = {
        let view = ImageButton(size: CGSize(width: 32, height: 32))
        view.sora.tintColor = .fgSecondary
        view.sora.image = R.image.wallet.info24()
        return view
    }()
    
    public var isSelectedMarket: Bool = false {
        didSet {
            checkmarkImageView.sora.isHidden = !isSelectedMarket
        }
    }
    
    public let type: LiquiditySourceType
    
    init(type: LiquiditySourceType) {
        self.type = type
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.sora.text = type.titleForLocale(.current)
        setup()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        sora.backgroundColor = .custom(uiColor: .clear)
        addSubviews(checkmarkImageView, titleLabel, infoButton)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            checkmarkImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            checkmarkImageView.centerYAnchor.constraint(equalTo: infoButton.centerYAnchor),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 24),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: checkmarkImageView.trailingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: infoButton.centerYAnchor),
            
            infoButton.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            infoButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            infoButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            infoButton.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            infoButton.heightAnchor.constraint(equalToConstant: 32),
            infoButton.widthAnchor.constraint(equalToConstant: 32),
        ])
    }
}
