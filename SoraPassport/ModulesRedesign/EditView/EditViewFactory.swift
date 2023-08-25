import Foundation

final class EditViewFactory: EditViewFactoryProtocol {
    static func createView(poolsService: PoolsServiceInputProtocol,
                           completion: (() -> Void)?) -> EditViewController {
        let editViewService = EditViewService(poolsService: poolsService)
        
        let viewModel = EditViewModel(editViewService: editViewService,
                                      completion: completion)
        
        let view = EditViewController(viewModel: viewModel)
        viewModel.view = view
        return view
    }
}




