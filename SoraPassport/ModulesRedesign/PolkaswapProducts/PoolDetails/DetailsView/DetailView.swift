import Foundation
import SoraUIKit
import UIKit

final class DetailView: SoramitsuControl {

    let leftInfoStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.alignment = .leading
        view.spacing = 4
        return view
    }()
    
    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    let infoButton: ImageButton = {
        let view = ImageButton(size: CGSize(width: 14, height: 14))
        view.sora.isHidden = true
        view.sora.tintColor = .fgSecondary
        view.sora.image = R.image.wallet.info()
        return view
    }()
    
    let rightInfoStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.alignment = .center
        view.spacing = 8
        return view
    }()
    
    let assetImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 16).isActive = true
        view.widthAnchor.constraint(equalToConstant: 16).isActive = true
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }()
    
    let valueLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.sora.backgroundColor = .custom(uiColor: .clear)
        return label
    }()
    
    let fiatValueLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.backgroundColor = .custom(uiColor: .clear)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    let progressView: ProgressView = {
        let view = ProgressView()
        view.sora.isHidden = true
        view.sora.cornerRadius = .circle
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.heightAnchor.constraint(equalToConstant: 4).isActive = true
        return view
    }()
    
    init() {
        super.init(frame: .zero)
        setup()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        sora.backgroundColor = .custom(uiColor: .clear)
        
        addSubviews(leftInfoStackView, rightInfoStackView)
        
        leftInfoStackView.addArrangedSubviews(titleLabel, infoButton)
        rightInfoStackView.addArrangedSubviews(progressView, assetImageView, valueLabel, fiatValueLabel)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            leftInfoStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            leftInfoStackView.centerYAnchor.constraint(equalTo: rightInfoStackView.centerYAnchor),
            leftInfoStackView.trailingAnchor.constraint(lessThanOrEqualTo: rightInfoStackView.leadingAnchor),
            
            rightInfoStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rightInfoStackView.topAnchor.constraint(equalTo: topAnchor),
            rightInfoStackView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
