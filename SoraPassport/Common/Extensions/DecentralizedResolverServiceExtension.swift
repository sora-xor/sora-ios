import Foundation

extension DecentralizedResolverService {
    static func createDefault() -> DecentralizedResolverService? {
        guard let url = URL(string: ApplicationConfig.shared.didResolverUrl) else {
            return nil
        }

        return DecentralizedResolverService(url: url)
    }
}
