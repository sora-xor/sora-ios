import UIKit

public enum InputTextViewState {
    case `default`
    case focused
    case success
    case fail
    case disabled

    var isResultState: Bool {
        return self == .success || self == .fail
    }

    var borderColor: SoramitsuColor {
        switch self {
        case .`default`: return .bgSurfaceVariant
        case .focused: return .fgPrimary
        case .success: return .statusSuccess
        case .fail: return .statusError
        case .disabled: return .fgPrimary
        }
    }

    var descriptionColor: SoramitsuColor {
        switch self {
        case .`default`, .focused: return .fgSecondary
        case .success: return .statusSuccess
        case .fail: return .statusError
        case .disabled: return .fgPrimary
        }
    }
}

public final class InputTextViewConfiguration<Type: InputTextView>: SoramitsuViewConfiguration<Type> {
    public var state: InputTextViewState = .default {
        didSet(oldState) {
            if (oldState.isResultState && state == .focused) || (oldState.isResultState && state == .default) {
                state = oldState
            }
            updateView()
        }
    }

    public var text: String? {
        set {
            owner?.textView.sora.text = newValue
        }
        get {
            owner?.textView.sora.text
        }
    }

    public var descriptionLabelText: String? {
        didSet {
            owner?.descriptionLabel.sora.text = descriptionLabelText
            owner?.descriptionLabel.sora.isHidden = descriptionLabelText == nil
        }
    }

    public var isEnabled: Bool = true {
        didSet {
            owner?.isUserInteractionEnabled = isEnabled
            state = isEnabled ? .default : .disabled
        }
    }

    public var keyboardType: UIKeyboardType = .default {
        didSet {
            owner?.textView.keyboardType = keyboardType
        }
    }

    public var textContentType: UITextContentType = .name {
        didSet {
            owner?.textView.textContentType = textContentType
        }
    }

    private var textObservation: NSKeyValueObservation?

    init(style: SoramitsuStyle, state: InputTextViewState) {
        self.state = state
        super.init(style: style)
        updateView()
    }

    public override func styleDidChange(options: UpdateOptions) {
        super.styleDidChange(options: options)

        if options.contains(.palette) {
            updateView()
        }
    }

    func updateView() {
        if isEnabled {
            owner?.stackView.layer.borderColor = style.palette.color(state.borderColor).cgColor
            owner?.stackView.backgroundColor = style.palette.color(.bgSurface)
            owner?.descriptionLabel.sora.textColor = state.descriptionColor
        } else {
            owner?.stackView.layer.borderColor = style.palette.color(state.borderColor).withAlphaComponent(0.04).cgColor
            owner?.stackView.backgroundColor = style.palette.color(.fgPrimary).withAlphaComponent(0.04)
            owner?.descriptionLabel.sora.textColor = .custom(uiColor: style.palette.color(state.descriptionColor).withAlphaComponent(0.04))
        }
    }
}
