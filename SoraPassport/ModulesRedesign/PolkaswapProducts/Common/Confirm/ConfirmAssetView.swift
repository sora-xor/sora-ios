import Foundation
import SoraUIKit
import UIKit

final class ConfirmAssetView: SoramitsuStackView {

    public let imageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.heightAnchor.constraint(equalToConstant: 48).isActive = true
        view.widthAnchor.constraint(equalToConstant: 48).isActive = true
        return view
    }()
    
    public let amountLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldS
        label.sora.textColor = .fgPrimary
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    public let symbolLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    
    init() {
        super.init(frame: .zero)
        setup()
        sora.alignment = .center
        sora.axis = .vertical
        spacing = 8
        layoutMargins = UIEdgeInsets(top: 24, left: 0, bottom: 24, right: 0)
        isLayoutMarginsRelativeArrangement = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        sora.backgroundColor = .custom(uiColor: .clear)
        
        addArrangedSubviews(imageView, amountLabel, symbolLabel)
    }
}
