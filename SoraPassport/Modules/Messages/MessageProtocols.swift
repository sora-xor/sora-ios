import UIKit

public protocol SoraMessageBuilderProtocol {
    func with(title: String?) -> Self
    func with(subtitle: String?) -> Self
    func with(image: UIImage?) -> Self
    func build() -> SoraMessageProtocol
}

public protocol MessageViewProtocol: class {
    func set(message: SoraMessageProtocol)
}

public protocol MessageViewWireframeProtocol: class {
    func show(message: SoraMessageProtocol, on window: UIWindow, animated: Bool)
    func hide(on window: UIWindow, animated: Bool)
}

public protocol MessageViewFactoryProtocol: class {
    func createMessageView() -> MessageViewProtocol
}

public protocol MessageViewDisplayProtocol: class {
    func show(message: SoraMessageProtocol, on window: UIWindow?)
}

extension MessageViewDisplayProtocol {
    public func show(message: SoraMessageProtocol, on window: UIWindow?) {
        let currentWindow = window ?? UIApplication.shared.delegate?.window as? UIWindow
        if let existingWindow = currentWindow {
            MessageViewWireframe.shared.show(message: message, on: existingWindow, animated: true)
        }
    }
}
