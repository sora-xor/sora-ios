import Foundation

protocol EditViewFactoryProtocol: AnyObject {
    static func createView() -> EditViewController
}

final class EditViewFactory: EditViewFactoryProtocol {
    static func createView() -> EditViewController {
        let viewModel = EditViewModel(itemFactory: EditViewItemFactory())
        
        let view = EditViewController(viewModel: viewModel)
        viewModel.view = view
        return view
    }
}




