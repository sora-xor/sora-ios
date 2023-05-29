import UIKit
import SoraUIKit
import CommonWallet
import RobinHood
import SoraFoundation

protocol SwapDisclaimerViewModelProtocol: AnyObject {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    func viewDidLoad()
}

final class SwapDisclaimerViewModel {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    weak var view: SwapDisclaimerViewProtocol?
    var completion: (() -> Void)?
}

extension SwapDisclaimerViewModel: SwapDisclaimerViewModelProtocol {
    func viewDidLoad() {
        let disclamerItem = SwapDisclaimerItem()
        disclamerItem.closeButtonHandler = { [weak self] in
            
            self?.view?.dismissDisclaimer(completion: self?.completion)
        }
        setupItems?([disclamerItem])
    }
}
