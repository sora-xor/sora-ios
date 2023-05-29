import Foundation
import SoraUIKit
import UIKit

struct InputAccessoryVariant {
    let displayValue: String
    let value: Float
}

protocol InputAccessoryViewDelegate: AnyObject {
    func didSelect(variant: Float)
}

final class InputAccessoryView: SoramitsuView {
    
    weak var delegate: InputAccessoryViewDelegate?

    public var variants: [InputAccessoryVariant] = [] {
        didSet {
            variants.enumerated().forEach { (index, variant) in
                let button = SoramitsuButton()
                button.translatesAutoresizingMaskIntoConstraints = false
                button.sora.backgroundColor = .custom(uiColor: .clear)
                button.sora.horizontalOffset = 10
                button.sora.attributedText = SoramitsuTextItem(text: variant.displayValue,
                                                               fontData: FontType.paragraphL,
                                                               textColor: .fgPrimary,
                                                               alignment: .center)
                button.sora.addHandler(for: .touchUpInside) { [weak self] in
                    self?.delegate?.didSelect(variant: variant.value)
                }
                stackView.addArrangedSubviews(button)
                
                if index != variants.count - 1 {
                    let separatorView = SoramitsuView()
                    separatorView.widthAnchor.constraint(equalToConstant: 1).isActive = true
                    separatorView.heightAnchor.constraint(equalToConstant: 25).isActive = true
                    separatorView.sora.backgroundColor = .custom(uiColor: UIColor(hex: "#b1b5bb"))
                    stackView.addArrangedSubview(separatorView)
                }
            }
        }
    }
    let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.alignment = .center
        view.sora.distribution = .fillProportionally
        view.clipsToBounds = false
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        clipsToBounds = false
        sora.backgroundColor = .custom(uiColor: UIColor(hex: "#d3d1d8"))
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 48),
        ])
    }
}
