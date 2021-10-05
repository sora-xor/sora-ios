import Foundation
import RobinHood
import FearlessUtils

typealias RuntimeMetadataClosure = () throws -> RuntimeMetadata

protocol RuntimeRegistryServiceProtocol: ApplicationServiceProtocol {
    func update(to chain: Chain, forced: Bool)
}

protocol RuntimeCodingServiceProtocol {
    func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: RuntimeMetadataClosure?)
    -> BaseOperation<RuntimeCoderFactoryProtocol>
}

extension RuntimeCodingServiceProtocol {
    func fetchCoderFactoryOperation(with timeout: TimeInterval) -> BaseOperation<RuntimeCoderFactoryProtocol> {
        fetchCoderFactoryOperation(with: timeout, closure: nil)
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        fetchCoderFactoryOperation(with: 120, closure: nil)
    }
}
