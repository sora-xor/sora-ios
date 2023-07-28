import Foundation
import IrohaCrypto
import RobinHood
import XNetworking

protocol APYServiceProtocol: AnyObject {
    func getApy(for baseAssetId: String, targetAssetId: String, completion: @escaping (Decimal?) -> Void)
    func getApy(for baseAssetId: String, targetAssetId: String) async -> Decimal?
}

final class APYService {
    static let shared = APYService()
    var polkaswapNetworkOperationFactory: PolkaswapNetworkOperationFactoryProtocol?
    private let operationManager: OperationManager = OperationManager()
    private var expiredDate: Date = Date()
    private var apy: [SbApyInfo] = []
}

extension APYService: APYServiceProtocol {
    
    @available(*, renamed: "getApy(for:targetAssetId:)")
    func getApy(for baseAssetId: String, targetAssetId: String, completion: @escaping (Decimal?) -> Void) {
        Task {
            let result = await getApy(for: baseAssetId, targetAssetId: targetAssetId)
            completion(result)
        }
    }
    
    
    func getApy(for baseAssetId: String, targetAssetId: String) async -> Decimal? {
        guard let factory = self.polkaswapNetworkOperationFactory,
              let poolPropertiesOperation = try? factory.poolProperties(baseAsset: baseAssetId, targetAsset: targetAssetId) else {
            return nil
        }
        
        let queryOperation = SubqueryApyInfoOperation<[SbApyInfo]>(baseUrl: ConfigService.shared.config.subqueryURL)
        
        return await withCheckedContinuation { continuation in
            queryOperation.completionBlock = { [weak self] in
                guard let self = self,
                      let reservesAccountData = try? poolPropertiesOperation.extractResultData()?.underlyingValue?.reservesAccountId,
                      let selectedAccount = SelectedWalletSettings.shared.currentAccount else {
                    return
                }
                
                let reservesAccountId = try? SS58AddressFactory().addressFromAccountId(data: reservesAccountData.value,
                                                                                       type: selectedAccount.networkType)
                
                guard self.expiredDate < Date() || self.apy.isEmpty else {
                    let apy = self.apy.first(where: { $0.id == reservesAccountId })
                    continuation.resume(returning: apy?.sbApy?.decimalValue)
                    return
                }
                
                guard let response = try? queryOperation.extractNoCancellableResultData() else {
                    continuation.resume(returning: nil)
                    return
                }
                let info = response.first(where: { $0.id == reservesAccountId })
                self.apy = response
                self.expiredDate = Date().addingTimeInterval(60)
                continuation.resume(returning: info?.sbApy?.decimalValue)
            }
            
            queryOperation.addDependency(poolPropertiesOperation)
            
            operationManager.enqueue(operations: [poolPropertiesOperation, queryOperation], in: .blockAfter)
        }
    }
}
