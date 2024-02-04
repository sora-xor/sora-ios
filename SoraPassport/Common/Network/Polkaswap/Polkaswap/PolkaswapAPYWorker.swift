import RobinHood
import SSFUtils
import sorawallet

protocol PolkaswapAPYWorker {
    func getAPYInfo() async throws -> [SbApyInfo]
}

final class PolkaswapAPYWorkerImpl: PolkaswapAPYWorker {
    let operationManager: OperationManagerProtocol
    
    init(operationManager: OperationManagerProtocol = OperationManager()) {
        self.operationManager = operationManager
    }
    
    func getAPYInfo() async throws -> [SbApyInfo] {
        let queryOperation = SubqueryApyInfoOperation<[SbApyInfo]>(baseUrl: ConfigService.shared.config.subqueryURL)
        operationManager.enqueue(operations: [queryOperation], in: .transient)
        
        return try await withCheckedThrowingContinuation { continuation in
            queryOperation.completionBlock = {
                do {
                    let response = try queryOperation.extractNoCancellableResultData()
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
