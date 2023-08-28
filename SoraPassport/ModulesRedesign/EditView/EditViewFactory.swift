import Foundation

final class EditViewFactory: EditViewFactoryProtocol {
    static func createView(poolsService: PoolsServiceInputProtocol,
                           editViewService: EditViewServiceProtocol,
                           completion: (() -> Void)?) -> EditViewController {
        
        let viewModel = EditViewModel(editViewService: editViewService,
                                      completion: completion)
        
        let view = EditViewController(viewModel: viewModel)
        viewModel.view = view
        return view
    }
}




