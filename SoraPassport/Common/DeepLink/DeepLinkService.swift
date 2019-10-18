import Foundation

protocol DeepLinkServiceProtocol: class {
    func handle(url: URL) -> Bool
}

final class DeepLinkService {
    static let shared = DeepLinkService()

    private(set) var children: [DeepLinkServiceProtocol] = []

    func setup(children: [DeepLinkServiceProtocol]) {
        self.children = children
    }

    func findService<T>() -> T? {
        return children.first(where: { $0 is T }) as? T
    }
}

extension DeepLinkService: DeepLinkServiceProtocol {
    func handle(url: URL) -> Bool {
        for child in children {
            if child.handle(url: url) {
                return true
            }
        }

        return false
    }
}
