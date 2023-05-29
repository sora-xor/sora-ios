import Foundation
import SoraUIKit
import UIKit

final class InputAssetsView: SoramitsuView {

    public var firstAsset: InputAssetField = {
        let field = InputAssetField()
        field.sora.assetArrow = R.image.wallet.arrow()
        field.sora.assetImage = R.image.wallet.emptyToken()
        field.textField.sora.placeholder = "0"
        field.sora.inputedFiatAmountText = "$0"
        field.translatesAutoresizingMaskIntoConstraints = false
        field.sora.state = .default
        field.textField.keyboardType = .decimalPad
        return field
    }()
    
    public let middleButton: ImageButton = {
        let view = ImageButton(size: CGSize(width: 24, height: 24))
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .circle
        return view
    }()
    
    public var secondAsset: InputAssetField = {
        let field = InputAssetField()
        field.sora.assetArrow = R.image.wallet.arrow()
        field.sora.assetImage = R.image.wallet.emptyToken()
        field.textField.sora.placeholder = "0"
        field.sora.inputedFiatAmountText = "$0"
        field.translatesAutoresizingMaskIntoConstraints = false
        field.sora.state = .default
        field.textField.keyboardType = .decimalPad
        return field
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
        translatesAutoresizingMaskIntoConstraints = false
        addSubviews(firstAsset, secondAsset, middleButton)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            firstAsset.leadingAnchor.constraint(equalTo: leadingAnchor),
            firstAsset.centerXAnchor.constraint(equalTo: centerXAnchor),
            firstAsset.topAnchor.constraint(equalTo: topAnchor),
            
            secondAsset.topAnchor.constraint(equalTo: firstAsset.bottomAnchor, constant: 8),
            secondAsset.leadingAnchor.constraint(equalTo: leadingAnchor),
            secondAsset.centerXAnchor.constraint(equalTo: centerXAnchor),
            secondAsset.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            middleButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            middleButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
