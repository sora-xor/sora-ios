import Foundation
import IrohaCrypto
import RobinHood
import XNetworking

protocol MarketCapServiceProtocol: AnyObject {
    func getMarketCap() async -> [AssetsInfo]
}

final class MarketCapService {
    private let operationManager: OperationManager = OperationManager()
    private var expiredDate: Date = Date()
    private var marketCap: [AssetsInfo] = []
    private weak var assetManager: AssetManagerProtocol?
    
    init(assetManager: AssetManagerProtocol?) {
        self.assetManager = assetManager
    }
}

extension MarketCapService: MarketCapServiceProtocol {
    
    func getMarketCap() async -> [AssetsInfo] {
        return await withCheckedContinuation { continuation in
            guard expiredDate < Date() || marketCap.isEmpty else {
                continuation.resume(returning: marketCap)
                return
            }
            
            let assetIds = assetManager?.getAssetList()?.map { $0.assetId } ?? []
            
            let queryOperation = SubqueryMarketCapInfoOperation<[AssetsInfo]>(baseUrl: ConfigService.shared.config.subqueryURL,
                                                                              assetIds: assetIds)
            
            queryOperation.completionBlock = {
                guard let response = try? queryOperation.extractNoCancellableResultData() else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: response)
            }
            
            operationManager.enqueue(operations: [queryOperation], in: .transient)
        }
    }
}
