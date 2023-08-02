import UIKit
import SoraUIKit
import SoraFoundation

protocol EditViewModelProtocol: AnyObject {
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    func updateItems()
}

final class EditViewModel {
    
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var items: [SoramitsuTableViewItemProtocol] = []
    
    weak var view: EditViewProtocol?
    var itemFactory: EditViewItemFactoryProtocol
    
    init(itemFactory: EditViewItemFactoryProtocol) {
        self.itemFactory = itemFactory
    }
}

extension EditViewModel: EditViewModelProtocol {
    
    func updateItems() {
        items = createItems()
        setupItems?(items)
    }
    
    private func createItems() -> [SoramitsuTableViewItemProtocol] {
        var items: [SoramitsuTableViewItemProtocol] = []
        
        let enabledItem = itemFactory.enabledItem(with: self)
        items.append(enabledItem)
        
        let disabledItem = itemFactory.disabledItem(with: self)
        items.append(disabledItem)
        
        return items
    }
}
