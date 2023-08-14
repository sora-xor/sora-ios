import UIKit
import SoraUIKit
import SoraFoundation
import Combine

final class EditViewModel {
    
    weak var view: EditViewControllerProtocol?
    @Published var snapshot: EditViewSnapshot = EditViewSnapshot()
    var snapshotPublisher: Published<EditViewSnapshot>.Publisher { $snapshot }
    
    var completion: (() -> Void)?
    
    init(completion: (() -> Void)?) {
        self.completion = completion
    }
}

extension EditViewModel: EditViewModelProtocol {
    
    func reloadView() {
        snapshot = createSnapshot()
    }
    
    private func createSnapshot() -> EditViewSnapshot {
        var snapshot = EditViewSnapshot()
        
        let sections = [ contentSection() ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
    
    private func contentSection() -> EnabledSection {
        let item = EnabledItem()
        
        item.enabledViewModels = Cards.allCases.map { card in
            EnabledViewModel(id: card.id,
                             title: card.title,
                             state: card.defaultState)
        }

        item.onTap = { [weak self, weak item] id in
            guard
                let item = item,
                let viewModel = item.enabledViewModels.first(where: { $0.id == id })
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

            self?.reloadView()
        }
        
        return EnabledSection(items: [.enabled(item)])
    }
}
