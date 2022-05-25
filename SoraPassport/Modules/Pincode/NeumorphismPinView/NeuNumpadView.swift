import UIKit

public protocol NeuNumpadDelegate: AnyObject {
    func numpadView(_ view: NeuNumpadView, didSelectNumAt index: Int)
    func numpadViewDidSelectBackspace(_ view: NeuNumpadView)
    func numpadViewDidSelectAccessoryControl(_ view: NeuNumpadView)
}

public protocol NeuNumpadAccessibilitySupportProtocol: AnyObject {
    func setupKeysAccessibilityIdWith(format: String?)
    func setupBackspace(accessibilityId: String?)
    func setupAccessory(accessibilityId: String?)
}

@IBDesignable
public class NeuNumpadView: UIView {

    @IBOutlet private var containerView: UIView!
    @IBOutlet private weak var rowHeight: NSLayoutConstraint!

    @IBOutlet var buttons: [NeumorphismButton]!
    @IBOutlet weak var backspaceButton: NeumorphismButton!
    @IBOutlet weak var accessoryButton: NeumorphismButton!
    private var accessoryButtonId: String?

    public weak var delegate: NeuNumpadDelegate?

    public var supportsAccessoryControl: Bool {
        get { return accessoryButton != nil }
        set(newValue) {
            accessoryButton.isHidden = !newValue
        }
    }

    public var keyRadius: CGFloat {
        get { return rowHeight.constant * 0.8 }
        set {
            rowHeight.constant = newValue * 1.0 / 0.8
            setNeedsLayout()
            layoutIfNeeded()
            buttons.forEach { button in
                button.layoutNeumorphismShadows()
            }
        }
    }

    public var backspaceIcon: UIImage? {
        didSet {
            backspaceButton.setImage(backspaceIcon, for: .normal)
        }
    }

    public var accessoryIcon: UIImage? {
        didSet {
            accessoryButton.setImage(accessoryIcon, for: .normal)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        initNib()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initNib()
    }

    func initNib() {
        backgroundColor = .clear

        let bundle = Bundle(for: NeuNumpadView.self)
        bundle.loadNibNamed("NeuNumpadView", owner: self, options: nil)
        addSubview(containerView)
        containerView.frame = bounds
        containerView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        configureButtons()
    }

    private func configureButtons() {
        for button in buttons {
            if button == backspaceButton {
                button.button.setImage(R.image.pin.delete(), for: .normal)
            } else if button == accessoryButton {
                button.accessibilityIdentifier = accessoryButtonId
                button.button.setImage(R.image.pin.faceID(), for: .normal)
            } else {
                let attributes: [NSAttributedString.Key: Any] = [
                    NSAttributedString.Key.font: UIFont.styled(for: .button, isBold: true).withSize(34),
                    NSAttributedString.Key.foregroundColor: R.color.neumorphism.text()!
                ]
                let attributedTitle = NSAttributedString(string: String(button.button.tag), attributes: attributes)
                button.setAttributedTitle(attributedTitle, for: .normal)
            }
        }
    }

    @IBAction func didPressNumber(_ button: NeumorphismButton) {
        delegate?.numpadView(self, didSelectNumAt: button.tag)
    }

    @IBAction func didPressBackspace(_ button: NeumorphismButton) {
        delegate?.numpadViewDidSelectBackspace(self)
    }

    @IBAction func didPressAccessory(_ button: NeumorphismButton) {
        delegate?.numpadViewDidSelectAccessoryControl(self)
    }
}

extension NeuNumpadView: NeuNumpadAccessibilitySupportProtocol {

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
