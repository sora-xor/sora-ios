import Foundation
import SoraUIKit
import UIKit

final class ActivityDetailView: SoramitsuControl {
    
    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        return label
    }()
    
    let valueLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textXS
        label.sora.textColor = .fgPrimary
        label.sora.backgroundColor = .custom(uiColor: .clear)
        label.sora.numberOfLines = 0
        return label
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
        
        addSubviews(titleLabel, valueLabel)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: valueLabel.topAnchor, constant: -4),
            
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            valueLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }
}
