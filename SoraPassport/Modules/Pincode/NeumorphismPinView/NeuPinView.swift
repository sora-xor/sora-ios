import UIKit
import AudioToolbox
import Anchorage

public protocol NeuPinViewDelegate: AnyObject {
    /**
     *  Called when current input field becomes filled.
     *  - parameters:
     *      - pinView: current input pin view
     *      - result: string entered by the user
     */
    func didCompleteInput(pinView: NeuPinView, result: String)

    /**
     *  Called when state in create mode changes.
     *  - parameters:
     *      - pinView: current input pin view
     *      - state: previous state
     */
    func didChange(pinView: NeuPinView, from state: NeuPinView.CreationState)

    /**
     *  Called when user selects accessory control.
     *  - parameters:
     *      - pinView: current input pin view
     */
    func didSelectAccessoryControl(pinView: NeuPinView)

    /**
     *  Called on wrong confirmation of pin.
     *  - parameters:
     *      - pinView: current input pin view
     */
    func didFailConfirmation(pinView: NeuPinView)
}

public protocol PinViewAccessibilitySupportProtocol: AnyObject {
    func setupInputField(accessibilityId: String?)
}

public class NeuPinView: UIView {

    @IBOutlet private var containerView: UIView!
    @IBOutlet private weak var stack: UIStackView!
    private var animationView = UIView()
    public let numpad = NeuNumpadView(frame: .zero)
    public let symbols = NeuPinSymbolsView(frame: .zero)

    private var createdCharacters: [Character]?

    public enum Mode: Int8 {
        case create = 0
        case securedInput = 1
        case unsecuredInput = 2
    }

    /**
     *  Use `create` mode to request pin setup and `unsecuredInput` or `securedInput`
     *  to request pin enter from the user. By default `unsecuredInput`.
     */
    public var mode = Mode.unsecuredInput {
        didSet {
            if oldValue != mode {
                createdCharacters = nil
                creationState = .normal
                symbols.clear()
            }
        }
    }

    public enum CreationState {
        case normal
        case confirm
    }

    /// State of the in `create` mode. This value is ignored for other modes.
    public private(set) var creationState = CreationState.normal

    public var errorAnimationDuration: CGFloat = 0.5
    public var errorAnimationAmplitude: CGFloat = 20.0
    public var errorAnimationDamping: CGFloat = 0.4
    public var errorAnimationInitialVelocity: CGFloat = 1.0
    public var errorAnimationAnimationOptions: UIView.AnimationOptions = .curveEaseInOut

    public weak var delegate: NeuPinViewDelegate?

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

        let bundle = Bundle(for: NeuPinView.self)
        bundle.loadNibNamed("NeuPinView", owner: self, options: nil)
        addSubview(containerView)
        containerView.frame = bounds
        containerView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        setupSymbolsView()
        setupNumpadView()
    }

    func setupNumpadView() {
        numpad.delegate = self
        stack.addArrangedSubview(numpad)
    }

    func setupSymbolsView() {
        
        animationView.backgroundColor = UIColor.clear
        animationView.addSubview(symbols)
        stack.addArrangedSubview(animationView)
        symbols.topAnchor == animationView.topAnchor
        symbols.bottomAnchor == animationView.bottomAnchor
        symbols.leftAnchor == animationView.leftAnchor
        symbols.rightAnchor == animationView.rightAnchor
        symbols.clear()
    }
    
    // MARK: Delegate Handling

    private func notifyDelegateOnCompletion() {
        self.delegate?.didCompleteInput(pinView: self, result: String(symbols.allCharacters()))
    }

    private func notifyDelegateOnStateChange(from state: CreationState) {
        self.delegate?.didChange(pinView: self, from: state)
    }

    private func notifyDelegateOnWrongInputError() {
        self.delegate?.didFailConfirmation(pinView: self)
    }

    // Fields View Processing

    private func didCompleteInput() {
        switch mode {
        case .create:
            handleCreationInputCompletion()
        case .securedInput:
            notifyDelegateOnCompletion()
        case .unsecuredInput:
            notifyDelegateOnCompletion()
        }
    }

    private func handleCreationInputCompletion() {
        switch creationState {
        case .normal:
            creationState = .confirm
            createdCharacters = symbols.characters

            switchToConfirmationState(animated: true)
            notifyDelegateOnStateChange(from: .normal)
        case .confirm:
            if symbols.characters != createdCharacters {
                animateWrongInputError()
                symbols.clear()
                notifyDelegateOnWrongInputError()
            } else {
                notifyDelegateOnCompletion()
            }
        }
    }

    private func switchToConfirmationState(animated: Bool) {
        symbols.clear()

        if animated {
            let animation = CATransition()
            animation.type = CATransitionType.push
            animation.subtype = CATransitionSubtype.fromRight
            animationView.layer.add(animation, forKey: "state.confirm")
        }
    }

    private func switchToNormalState(animated: Bool) {
        symbols.clear()

        if animated {
            let animation = CATransition()
            animation.type = CATransitionType.push
            animation.subtype = CATransitionSubtype.fromLeft
            animationView.layer.add(animation, forKey: "state.normal")
        }
    }

    private func animateWrongInputError() {
        animationView.transform = CGAffineTransform(translationX: errorAnimationAmplitude, y: 0)
        UIView.animate(withDuration: TimeInterval(errorAnimationDuration),
                       delay: 0,
                       usingSpringWithDamping: errorAnimationDamping,
                       initialSpringVelocity: errorAnimationInitialVelocity,
                       options: errorAnimationAnimationOptions,
                       animations: { [weak self] in
            self?.animationView.transform = CGAffineTransform.identity
        }, completion: nil)
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    }

    public func reset(shouldAnimateError: Bool) {
        symbols.clear()
        if shouldAnimateError {
            animateWrongInputError()
        }
    }

    public func resetCreationState(animated: Bool) {
        guard mode == .create else { return }

        symbols.clear()

        if creationState == .confirm {
            clearCreationState()
            switchToNormalState(animated: animated)
        }
    }

    private func clearCreationState() {
        createdCharacters = nil
        creationState = .normal
    }

}

extension NeuPinView: NeuNumpadDelegate {
    public func numpadView(_ view: NeuNumpadView, didSelectNumAt index: Int) {
        guard !symbols.isComplete else {
            didCompleteInput()
            return
        }
        symbols.append(character: Character(String(index)))
        if symbols.isComplete {
            didCompleteInput()
        }
    }

    public func numpadViewDidSelectBackspace(_ view: NeuNumpadView) {
        if !symbols.isEmpty {
            symbols.removeLastCharacter()
        }
    }

    public func numpadViewDidSelectAccessoryControl(_ view: NeuNumpadView) {
        delegate?.didSelectAccessoryControl(pinView: self)
    }
}

extension NeuPinView: PinViewAccessibilitySupportProtocol {
    public func setupInputField(accessibilityId: String?) {
        symbols.accessibilityIdentifier = accessibilityId
    }
}
