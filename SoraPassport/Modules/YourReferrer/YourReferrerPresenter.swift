import Foundation

protocol YourReferrerPresenterOutput {}

final class YourReferrerPresenter: YourReferrerPresenterOutput {
    weak var view: YourReferrerViewInput?
    private var items: [CellViewModel] = []
    private var referrer: String
    
    init(referrer: String) {
        self.referrer = referrer
    }
}

extension YourReferrerPresenter: YourReferrerViewOutput {
    func willMove() {
        items.append(YourReferrerViewModel(referrer: referrer,
                                           delegate: self))
        
        DispatchQueue.main.async {
            self.view?.setup(with: self.items)
        }
    }
}

extension YourReferrerPresenter: YourReferrerCellDelegate {
    func closeTapped() {
        self.view?.pop()
    }
}
