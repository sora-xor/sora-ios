import UIKit
import SoraUIKit
import CommonWallet
import RobinHood
import SoraFoundation

protocol ChoiceMarketViewModelProtocol: AnyObject {
    var selectedMarket: LiquiditySourceType { get set }
    func viewDidLoad()
}

final class ChoiceMarketViewModel {
    
    weak var view: ChoiceMarketViewProtocol?
    var completion: ((LiquiditySourceType) -> Void)?
    var wireframe: AlertPresentable?
    var markets: [LiquiditySourceType]
    var selectedMarket: LiquiditySourceType {
        didSet {
            view?.setup(selectedMarket: selectedMarket)
            completion?(selectedMarket)
        }
    }
    
    init(markets: [LiquiditySourceType], selectedMarket: LiquiditySourceType) {
        self.markets = markets
        self.selectedMarket = selectedMarket
    }
}

extension ChoiceMarketViewModel: ChoiceMarketViewModelProtocol {
    func viewDidLoad() {
        view?.setup(markets: markets)
        view?.setup(selectedMarket: selectedMarket)
    }
}
