import Foundation
import UIKit
import SoraFoundation

class PolkaswapSlippageHelperTextField: UITextField {
    var slippageView: PolkaswapSlippageSelectorView? = {
        let view = R.nib.polkaswapSlippageSelectorView(owner: nil, options: nil)!
        view.localizationManager = LocalizationManager.shared
        let presenter = PolkaswapSlippageSelectorPresenter(amountFormatterFactory: AmountFormatterFactory())
        presenter.view = view
        view.presenter = presenter
        presenter.setup(preferredLocalizations: LocalizationManager.shared.preferredLocalizations)
        
        return view
    }()

    override var inputAccessoryView: UIView? {
        get {
            return slippageView
        }
        set {
            slippageView = newValue as? PolkaswapSlippageSelectorView
        }
    }

    override var canResignFirstResponder: Bool {
        return true
    }
    
    func dismissSlippageView() {
        slippageView?.dismiss()
    }
}
