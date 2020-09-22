import UIKit

public protocol SoraMessageProtocol {
    var title: String? { get }
    var subtitle: String? { get }
    var image: UIImage? { get }
}

public struct SoraMessage: SoraMessageProtocol, Equatable {
    public var title: String?
    public var subtitle: String?
    public var image: UIImage?
}

public class SoraMessageBuilder: SoraMessageBuilderProtocol {
    private lazy var message = SoraMessage()

    public func with(title: String?) -> Self {
        message.title = title
        return self
    }

    public func with(subtitle: String?) -> Self {
        message.subtitle = subtitle
        return self
    }

    public func with(image: UIImage?) -> Self {
        message.image = image
        return self
    }

    public func build() -> SoraMessageProtocol {
        return message
    }
}
