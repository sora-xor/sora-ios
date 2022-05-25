import Foundation

enum ViewModelState<ViewModel> {
    case data(viewModel: ViewModel)
    case loading(viewModel: ViewModel)
    case empty

    var viewModel: ViewModel? {
        switch self {
        case .data(let viewModel):
            return viewModel
        case .loading(let viewModel):
            return viewModel
        case .empty:
            return nil
        }
    }
}
