import Foundation
import IrohaCrypto
import RobinHood
import XNetworking

protocol APYServiceProtocol: AnyObject {
    func getApy(for baseAssetId: String, targetAssetId: String, completion: @escaping (SbApyInfo?) -> Void)
}

final class APYService {
    static let shared = APYService()
    var polkaswapNetworkOperationFactory: PolkaswapNetworkOperationFactoryProtocol?
    private let operationManager: OperationManager = OperationManager()
    private var expiredDate: Date = Date()
    private var apy: [SbApyInfo] = []
}

extension APYService: APYServiceProtocol {
    
    func getApy(for baseAssetId: String, targetAssetId: String, completion: @escaping (SbApyInfo?) -> Void) {
        guard let poolPropertiesOperation = try? self.polkaswapNetworkOperationFactory?.poolProperties(baseAsset: baseAssetId,
                                                                                                       targetAsset: targetAssetId) else { return }

        let queryOperation = SubqueryApyInfoOperation<[SbApyInfo]>(baseUrl: ConfigService.shared.config.subqueryURL)
        
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
                completion(apy)
                return
            }
            
            guard let response = try? queryOperation.extractNoCancellableResultData() else {
                completion(nil)
                return
            }
            let info = response.first(where: { $0.id == reservesAccountId })
            self.apy = response
            self.expiredDate = Date().addingTimeInterval(60)
            completion(info)
        }
        
        queryOperation.addDependency(poolPropertiesOperation)
        
        operationManager.enqueue(operations: [poolPropertiesOperation, queryOperation], in: .blockAfter)
    }
}
