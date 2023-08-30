import UIKit
import SoraUIKit
import SoraFoundation
import Combine

final class EditViewModel {
    
    weak var view: EditViewControllerProtocol?
    @Published var snapshot: EditViewSnapshot = EditViewSnapshot()
    var snapshotPublisher: Published<EditViewSnapshot>.Publisher { $snapshot }
    
    var editViewService: EditViewServiceProtocol
    var completion: (() -> Void)?
    
    init(editViewService: EditViewServiceProtocol,
         completion: (() -> Void)?) {
        self.editViewService = editViewService
        self.completion = completion
    }
}

extension EditViewModel: EditViewModelProtocol {
    
    func reloadView(with section: EnabledSection?) {
        guard let section = section else {
            snapshot = createSnapshot(with: contentSection())
            return
        }
        
        snapshot = createSnapshot(with: section)
    }
    
    private func createSnapshot(with section: EnabledSection) -> EditViewSnapshot {
        var snapshot = EditViewSnapshot()
        
        let sections = [ section ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
    
    private func contentSection() -> EnabledSection {
        let item = EnabledItem()
        
        item.enabledViewModels = editViewService.viewModels

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

            self?.reloadView(with: EnabledSection(items: [.enabled(item)]))
        }
        
        return EnabledSection(items: [.enabled(item)])
    }
}
