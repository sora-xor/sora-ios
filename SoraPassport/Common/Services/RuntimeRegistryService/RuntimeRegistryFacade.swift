import Foundation
import RobinHood
import SoraKeystore

final class RuntimeRegistryFacade {
    @available(*, deprecated, message: "Will be removed after tests update")
    static let sharedService: RuntimeRegistryServiceProtocol & RuntimeCodingServiceProtocol = {
        let chain = Chain.sora

        return RuntimeRegistryService(
            chain: chain,
            chainRegistry: ChainRegistryFacade.sharedRegistry
        )
    }()
}
