import UIKit
import SoraFoundation

protocol PolkaswapAmountFieldAccessoryDelegate: AnyObject {
    func donePressed(amountField: PolkaswapAmountField)
    func predefinedPressed(amountField: PolkaswapAmountField, value: Int)
}

class PolkaswapAmountField: NeuTextField {
    weak var accessoryDelegate: PolkaswapAmountFieldAccessoryDelegate?
    var predefinedValues: [Int] = []
    var predifinedValueTitles: [String] {
        predefinedValues.map { predefinedValue in
            return "\(predefinedValue)%"
        }
    }
    lazy var accessoryView: PolkaswapAmountAccessoryView? = {
        let view = R.nib.polkaswapAmountAccessoryView(owner: nil, options: nil)!
        let doneButtonText = R.string.localizable.commonDone(preferredLanguages: languages).uppercased()
        let viewModel = PolkaswapAmountAccessoryViewModel(doneButtonText: doneButtonText, selectionButtons: predifinedValueTitles)
        view.setViewModel(viewModel)
        view.delegate = self

        return view
    }()

    override var inputAccessoryView: UIView? {
        get {
            return accessoryView
        }
        set {
            accessoryView = newValue as? PolkaswapAmountAccessoryView
        }
    }

    override var canResignFirstResponder: Bool {
        return true
    }
}

extension PolkaswapAmountField: PolkaswapAmountAccessoryViewDelegate {
    func donePressed() {
        accessoryDelegate?.donePressed(amountField: self)
    }

    func predefinedPressed(atIndex: Int) {
        accessoryDelegate?.predefinedPressed(amountField: self, value: predefinedValues[atIndex])
    }
}

extension PolkaswapAmountField: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        let doneButtonText = R.string.localizable.commonDone(preferredLanguages: languages).uppercased()
        let viewModel = PolkaswapAmountAccessoryViewModel(doneButtonText: doneButtonText, selectionButtons: predifinedValueTitles)
        accessoryView?.setViewModel(viewModel)
    }
}
