import Foundation
import RobinHood

protocol WhitelistOperationFactoryProtocol {
    func fetchWhiteListOperation(for chain: Chain) -> BaseOperation<Data?>
}

class WhitelistOperationFactory: WhitelistOperationFactoryProtocol {
    let repository: FileRepositoryProtocol

    init(repository: FileRepositoryProtocol) {
        self.repository = repository
    }

    func fetchWhiteListOperation(for chain: Chain) -> BaseOperation<Data?> {
        guard let filePath = chain.preparedWhiteListPath() else {
            return BaseOperation.createWithError(BaseOperationError.parentOperationCancelled)
        }
        let readOperation = repository.readOperation(at: filePath)
        return readOperation
    }
}
