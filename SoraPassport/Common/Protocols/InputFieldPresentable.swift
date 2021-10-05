import UIKit

protocol InputFieldPresentable {
    func requestInput(for viewModel: InputFieldViewModelProtocol,
                      from view: ControllerBackedProtocol?)
}

extension InputFieldPresentable {
    func requestInput(for viewModel: InputFieldViewModelProtocol,
                      from view: ControllerBackedProtocol?) {

        var currentController = view?.controller

        if currentController == nil {
            currentController = UIApplication.shared.delegate?.window??.rootViewController
        }

        guard let presentingController = currentController else {
            return
        }

        let presenter = AlertInputFieldPresenter(viewModel: viewModel)
        presenter.present(from: presentingController)
    }
}
