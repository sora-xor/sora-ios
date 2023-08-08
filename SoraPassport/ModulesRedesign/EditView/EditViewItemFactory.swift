import Foundation
import SoraUIKit
import SoraFoundation

protocol EditViewItemFactoryProtocol: AnyObject {
    func enabledItem(with editViewModel: EditViewModel) -> SoramitsuTableViewItemProtocol
}

final class EditViewItemFactory: EditViewItemFactoryProtocol {
    
    func enabledItem(with editViewModel: EditViewModel) -> SoramitsuTableViewItemProtocol {
        let enabledItem = EnabledItem()
        let enabledIds = ApplicationConfig.shared.enabledCardIdentifiers
        
        let viewModels = Cards.allCases.map { card in
            EnabledViewModel(id: card.id,
                             title: card.title,
                             state: card.defaultState)
        }
        
        enabledItem.enabledViewModels = viewModels
        
        if enabledIds.isEmpty {
            ApplicationConfig.shared.enabledCardIdentifiers = viewModels.filter({ $0.state != .disabled }).map({ $0.id })
        }
        
        enabledItem.onTap = { [weak enabledItem] id in
            guard
                let enabledItem = enabledItem,
                let viewModel = enabledItem.enabledViewModels.first(where: { $0.id == id })
            else { return }
            
            switch viewModel.state {
            case .unselected:
                return
            case .selected:
                viewModel.state = .disabled
                ApplicationConfig.shared.enabledCardIdentifiers.removeAll(where: { $0 == viewModel.id })
            case .disabled:
                viewModel.state = .selected
                ApplicationConfig.shared.enabledCardIdentifiers.append(viewModel.id)
            }

            editViewModel.reloadItems?([enabledItem])
            editViewModel.completion?()
        }
        
        return enabledItem
    }
}
