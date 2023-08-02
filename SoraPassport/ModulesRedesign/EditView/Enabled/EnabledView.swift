import Foundation
import UIKit
import SoraUIKit
import SnapKit

final class EnabledView: SoramitsuView {
    
    public let stackView: SoramitsuStackView = {
        let stackView = SoramitsuStackView()
        stackView.sora.axis = .horizontal
        stackView.spacing = 8
        stackView.sora.isUserInteractionEnabled = false
        return stackView
    }()
    
    public let checkmarkButton: ImageButton = {
        let button = ImageButton(size: CGSize(width: 24, height: 24))
        button.sora.image = R.image.checkboxDefault()
        button.sora.isEnabled = false
        button.sora.isUserInteractionEnabled = false
        return button
    }()
    
    public let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .left
        label.sora.isUserInteractionEnabled = false
        return label
    }()

    public let tappableArea: SoramitsuControl = {
        let view = SoramitsuControl()
        view.sora.isHidden = true
        return view
    }()
    
    init() {
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

private extension EnabledView {
    func setup() {
        addSubview(stackView)
        addSubview(tappableArea)
        
        stackView.addArrangedSubviews([
            checkmarkButton,
            titleLabel
        ])
        
        tappableArea.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        
        stackView.snp.makeConstraints { make in
            make.leading.equalTo(self).offset(24)
            make.center.equalTo(self)
        }
    }
}
