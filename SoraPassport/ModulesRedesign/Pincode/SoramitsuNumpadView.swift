import Foundation
import SoraUIKit

public protocol SoramitsuNumpadDelegate: AnyObject {
    func numpadView(_ view: SoramitsuNumpadView, didSelectNumAt index: Int)
    func numpadViewDidSelectBackspace(_ view: SoramitsuNumpadView)
    func numpadViewDidSelectAccessoryControl(_ view: SoramitsuNumpadView)
}

public protocol SoramitsuNumpadAccessibilitySupportProtocol: AnyObject {
    func setupKeysAccessibilityIdWith(format: String?)
    func setupBackspace(accessibilityId: String?)
    func setupAccessory(accessibilityId: String?)
}

public class SoramitsuNumpadView: SoramitsuView {

    lazy var buttons: [SoramitsuButton] = {
        var buttons: [SoramitsuButton] = []
        for i in 0...10 {
            let text = SoramitsuTextItem(text: "\(i)",
                                         fontData: FontType.displayL,
                                         textColor: .fgSecondary,
                                         alignment: .center)
            let view = SoramitsuButton()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.sora.tintColor = .fgSecondary
            view.sora.backgroundColor = .bgSurface
            view.sora.shadow = .small
            view.sora.attributedText = text
            view.sora.cornerRadius = .circle
            view.widthAnchor.constraint(equalToConstant: 80).isActive = true
            view.heightAnchor.constraint(equalToConstant: 80).isActive = true
            view.sora.addHandler(for: .touchUpInside) { [weak self] in
                guard let self = self else { return }
                self.delegate?.numpadView(self, didSelectNumAt: i)
            }
            buttons.append(view)
        }
        return buttons
    }()
    
    lazy var backspaceButton: SoramitsuButton = {
        let view = SoramitsuButton()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.tintColor = .fgSecondary
        view.sora.backgroundColor = .bgSurface
        view.sora.shadow = .small
        view.sora.leftImage = R.image.wallet.delete()
        view.sora.imageSize = CGFloat(32)
        view.sora.cornerRadius = .circle
        view.widthAnchor.constraint(equalToConstant: 80).isActive = true
        view.heightAnchor.constraint(equalToConstant: 80).isActive = true
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            guard let self = self else { return }
            self.delegate?.numpadViewDidSelectBackspace(self)
        }
        return view
    }()
    
    lazy var accessoryButton: SoramitsuButton = {
        let view = SoramitsuButton()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.tintColor = .fgSecondary
        view.sora.backgroundColor = .bgSurface
        view.sora.shadow = .small
        view.sora.leftImage = R.image.wallet.faceId()
        view.sora.cornerRadius = .circle
        view.sora.imageSize = CGFloat(32)
        view.widthAnchor.constraint(equalToConstant: 80).isActive = true
        view.heightAnchor.constraint(equalToConstant: 80).isActive = true
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            guard let self = self else { return }
            self.delegate?.numpadViewDidSelectAccessoryControl(self)
        }
        return view
    }()
    
    private var accessoryButtonId: String?

    public weak var delegate: SoramitsuNumpadDelegate?

    init() {
        super.init(frame: .zero)
        setupView()
        setupConstraint()
    }

    func setupView() {
        sora.backgroundColor = .custom(uiColor: .clear)
        sora.clipsToBounds = false
    }
    
    func setupConstraint() {
        var mainStackView = SoramitsuStackView()
        mainStackView.sora.backgroundColor = .custom(uiColor: .clear)
        mainStackView.sora.axis = .vertical
        mainStackView.sora.distribution = .equalSpacing
        mainStackView.sora.alignment = .fill
        mainStackView.sora.clipsToBounds = false
        
        let firstRowStackView = SoramitsuStackView()
        firstRowStackView.translatesAutoresizingMaskIntoConstraints = false
        firstRowStackView.sora.backgroundColor = .custom(uiColor: .clear)
        firstRowStackView.sora.axis = .horizontal
        firstRowStackView.sora.distribution = .fillEqually
        firstRowStackView.sora.alignment = .fill
        firstRowStackView.sora.clipsToBounds = false
        firstRowStackView.spacing = 16
        firstRowStackView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        firstRowStackView.addArrangedSubviews(Array(buttons[1...3]))
        
        let secondRowStackView = SoramitsuStackView()
        secondRowStackView.translatesAutoresizingMaskIntoConstraints = false
        secondRowStackView.sora.backgroundColor = .custom(uiColor: .clear)
        secondRowStackView.sora.axis = .horizontal
        secondRowStackView.sora.distribution = .fillEqually
        secondRowStackView.sora.alignment = .fill
        secondRowStackView.sora.clipsToBounds = false
        secondRowStackView.spacing = 16
        secondRowStackView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        secondRowStackView.addArrangedSubviews(Array(buttons[4...6]))
        
        let thirdRowStackView = SoramitsuStackView()
        thirdRowStackView.translatesAutoresizingMaskIntoConstraints = false
        thirdRowStackView.sora.backgroundColor = .custom(uiColor: .clear)
        thirdRowStackView.sora.axis = .horizontal
        thirdRowStackView.sora.distribution = .fillEqually
        thirdRowStackView.sora.alignment = .fill
        thirdRowStackView.sora.clipsToBounds = false
        thirdRowStackView.spacing = 16
        thirdRowStackView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        thirdRowStackView.addArrangedSubviews(Array(buttons[7...9]))
        
        let forthRowStackView = SoramitsuStackView()
        forthRowStackView.translatesAutoresizingMaskIntoConstraints = false
        forthRowStackView.sora.backgroundColor = .custom(uiColor: .clear)
        forthRowStackView.sora.axis = .horizontal
        forthRowStackView.sora.distribution = .fillEqually
        forthRowStackView.sora.alignment = .fill
        forthRowStackView.spacing = 16
        forthRowStackView.sora.clipsToBounds = false
        forthRowStackView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        forthRowStackView.addArrangedSubviews([accessoryButton, buttons[0], backspaceButton])
        
        mainStackView.addArrangedSubviews(firstRowStackView, secondRowStackView, thirdRowStackView, forthRowStackView)
        
        addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: topAnchor),
            mainStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            mainStackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}

extension SoramitsuNumpadView: SoramitsuNumpadAccessibilitySupportProtocol {

    public func setupKeysAccessibilityIdWith(format: String?) {
        for button in buttons {
            if let existingFormat = format {
                button.accessibilityIdentifier = existingFormat + "\(button.tag)"
                button.accessibilityTraits = UIAccessibilityTraits.button
            } else {
                button.accessibilityIdentifier = nil
                button.accessibilityTraits = UIAccessibilityTraits.none
            }
        }
    }

    public func setupBackspace(accessibilityId: String?) {
        backspaceButton.accessibilityIdentifier = accessibilityId
    }

    public func setupAccessory(accessibilityId: String?) {
        accessoryButtonId = accessibilityId
        accessoryButton.accessibilityIdentifier = accessibilityId
    }
}
