import Foundation
import SoraUIKit
import UIKit

protocol SlippageToleranceViewDelegate: AnyObject {
    func slippageToleranceChanged(_ to: Float)
}

final class SlippageToleranceView: SoramitsuView {

    var delegate: SlippageToleranceViewDelegate?

    let stackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.alignment = .fill
        view.sora.distribution = .fill
        view.sora.cornerRadius = .max
        view.sora.shadow = .small
        view.spacing = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    public lazy var field: InputField = {
        let field = InputField()
        field.sora.state = .default
        field.textField.keyboardType = .decimalPad
        field.textField.returnKeyType = .done
        field.textField.tag = TextFieldTag.name.rawValue
        field.translatesAutoresizingMaskIntoConstraints = false
        field.textField.delegate = self
        field.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            guard let self = self else { return }
            
            var currentValue = Float(self.field.textField.text?
                .replacingOccurrences(of: "%", with: "", options: .literal, range: nil)
                .replacingOccurrences(of: ",", with: ".", options: .literal, range: nil) ?? "")
            
            if (self.field.textField.text?.contains("%") ?? false) {
                self.field.textField.sora.text?.removeLast()
            }

            if let value = currentValue, value > 10 {
                self.field.textField.sora.text = "10"
                currentValue = 10
            }
            
            if let text = self.field.textField.text {
                self.field.sora.text = "\(text)%"
            }
            
            if let value = currentValue {
                self.delegate?.slippageToleranceChanged(value)
            }
        }
        field.textField.autocorrectionType = .no
        return field
    }()
    
    public let descriptionLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textS
        label.sora.textColor = .fgPrimary
        label.sora.numberOfLines = 0
        label.sora.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.sora.text = R.string.localizable.polkaswapSlippageInfo(preferredLanguages: .currentLocale)
        return label
    }()
    
    public lazy var slipageButton: SoramitsuButton = {
        let button = SoramitsuButton()
        button.sora.backgroundColor = .additionalPolkaswap
        button.sora.horizontalOffset = 12
        button.sora.cornerRadius = .circle
        button.sora.title = R.string.localizable.commonDone(preferredLanguages: .currentLocale)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
        }
        return button
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
        clipsToBounds = false
        sora.backgroundColor = .custom(uiColor: .clear)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        stackView.addArrangedSubviews(field, descriptionLabel, slipageButton)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}

extension SlippageToleranceView: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return percentageLimit(textField: textField, string: string)
    }
    
    private func percentageLimit(textField: UITextField, string: String) -> Bool {
        let dotString = "."
        let commaString = ","

        guard let text = textField.text, text != dotString, text != commaString else { return false }

        if text.isEmpty && (string == dotString || string == commaString) { return false }

        let isDeleteKey = string.isEmpty

        if !isDeleteKey {
            if text.contains(dotString) {
                if text.components(separatedBy: dotString)[1].count == 2 || string == dotString {
                    return false
                }
            }
            if text.contains(commaString) {
                if text.components(separatedBy: commaString)[1].count == 2 || string == commaString {
                    return false
                }
            }
        }

        return true
    }
}
