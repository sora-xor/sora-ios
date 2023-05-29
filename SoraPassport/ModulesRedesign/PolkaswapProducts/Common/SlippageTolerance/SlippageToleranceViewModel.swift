import UIKit
import SoraUIKit
import CommonWallet
import RobinHood
import SoraFoundation

protocol SlippageToleranceViewModelProtocol: InputAccessoryViewDelegate, SlippageToleranceViewDelegate {
    func viewDidLoad()
    func doneButtonTapped()
}

final class SlippageToleranceViewModel {
    
    weak var view: SlippageToleranceViewProtocol?
    var completion: ((Float) -> Void)?
    var currentValue: Float {
        didSet {
            view?.setupDoneButton(isEnabled: currentValue != 0)
        }
    }
    
    init(value: Float) {
        self.currentValue = value
    }
}

extension SlippageToleranceViewModel: SlippageToleranceViewModelProtocol {
    func viewDidLoad() {
        view?.setup(tolerance: currentValue)
    }
    
    func doneButtonTapped() {
        view?.controller.navigationController?.popViewController(animated: true)
        completion?(currentValue)
    }
}

extension SlippageToleranceViewModel: InputAccessoryViewDelegate {
    func didSelect(variant: Float) {
        view?.setup(tolerance: variant)
        currentValue = variant
    }
}

extension SlippageToleranceViewModel: SlippageToleranceViewDelegate {
    func slippageToleranceChanged(_ to: Float) {
        currentValue = to
    }
}
