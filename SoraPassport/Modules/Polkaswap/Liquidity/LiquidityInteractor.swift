import CommonWallet
import FearlessUtils
import RobinHood

final class LiquidityInteractor {
    weak var presenter: LiquidityInteractorOutputProtocol!
    let networkFacade: WalletNetworkOperationFactoryProtocol
    let operationManager: OperationManagerProtocol

    init(operationManager: OperationManagerProtocol, networkFacade: WalletNetworkOperationFactoryProtocol) {
        self.operationManager = operationManager
        self.networkFacade = networkFacade
    }
}

extension LiquidityInteractor: LiquidityInteractorInputProtocol {
    func checkIsAvailable(firstAssetId: String, secondAssetId: String) {
        
        presenter.didCheckAvailable(
            firstAssetId: firstAssetId,
            secondAssetId: secondAssetId,
            isAvailable: true
        )
    }
    
    func loadBalance(asset: WalletAsset) {
        let operation = networkFacade.fetchBalanceOperation([asset.identifier])
            operation.targetOperation.completionBlock = {
                DispatchQueue.main.async {
                    if let balance = try? operation.targetOperation.extractResultData(), let balance = balance?.first {
                        self.presenter.didLoadBalance(balance.balance.decimalValue, asset: asset)
                    }
                }
            }
            operationManager.enqueue(operations: operation.allOperations, in: .blockAfter)
        
    }
    
}
