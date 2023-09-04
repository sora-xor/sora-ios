import Foundation

final class EditViewFactory: EditViewFactoryProtocol {
    static func createView(completion: (() -> Void)?) -> EditViewController {
        let viewModel = EditViewModel(completion: completion)
        
        let view = EditViewController(viewModel: viewModel)
        viewModel.view = view
        return view
    }
}




