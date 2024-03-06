import RobinHood
import SSFUtils
import sorawallet

enum PolkaswapAPYWorkerError: Swift.Error {
    case unexpectedError
}

public protocol PolkaswapAPYWorker {
    func getAPYInfo() async throws -> [SbApyInfo]
}

public final class PolkaswapAPYWorkerDefault: PolkaswapAPYWorker {
    private let operationManager: OperationManagerProtocol
    private let commonConfigUrlString: String
    private let mobileConfigUrlString: String
    private var subQueryClient: SoraWalletBlockExplorerInfo?
    
    init(
        commonUrl: String = ApplicationConfig.shared.commonConfigUrl,
        mobileUrl: String = ApplicationConfig.shared.mobileConfigUrl,
        operationManager: OperationManagerProtocol = OperationManager()
    ) {
        self.commonConfigUrlString = commonUrl
        self.mobileConfigUrlString = mobileUrl
        self.operationManager = operationManager
    }
    
    public func getAPYInfo() async throws -> [SbApyInfo] {
        let queryOperation = apyOperation()
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
    
    private func apyOperation() -> AwaitOperation<[SbApyInfo]> {
        return AwaitOperation {
            try await withCheckedThrowingContinuation { [weak self] continuation in
                guard let self else {
                    continuation.resume(throwing: PolkaswapAPYWorkerError.unexpectedError)
                    return
                }

                let httpProvider = SoramitsuHttpClientProviderImpl()
                
                let soraNetworkClient = SoramitsuNetworkClient(
                    timeout: 60000,
                    logging: true,
                    provider: httpProvider
                )

                let provider = SoraRemoteConfigProvider(
                    client: soraNetworkClient,
                    commonUrl: self.commonConfigUrlString,
                    mobileUrl: self.mobileConfigUrlString
                )

                let configBuilder = provider.provide()

                self.subQueryClient = SoraWalletBlockExplorerInfo(
                    networkClient: soraNetworkClient,
                    soraRemoteConfigBuilder: configBuilder
                )
                
                DispatchQueue.main.async {
                    self.subQueryClient?.getSpApy(completionHandler: { requestResult, error in
                        if let error {
                            continuation.resume(throwing: error)
                            return
                        }
                        
                        if let data = requestResult {
                            continuation.resume(returning: data)
                            return
                        }
                        
                        continuation.resume(throwing: PolkaswapAPYWorkerError.unexpectedError)
                    })
                }

            }
        }
    }
}
