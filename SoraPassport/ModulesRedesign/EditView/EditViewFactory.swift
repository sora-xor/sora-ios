import Foundation

protocol EditViewFactoryProtocol: AnyObject {
    static func createView(completion: (() -> Void)?) -> EditViewController
}

final class EditViewFactory: EditViewFactoryProtocol {
    static func createView(completion: (() -> Void)?) -> EditViewController {
        let viewModel = EditViewModel(itemFactory: EditViewItemFactory(),
                                      completion: completion)
        
        let view = EditViewController(viewModel: viewModel)
        viewModel.view = view
        return view
    }
}




