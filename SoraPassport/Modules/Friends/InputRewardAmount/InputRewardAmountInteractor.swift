import Foundation
import CommonWallet
import BigInt

protocol InputRewardAmountInteractorInputProtocol: AnyObject {
    func getBalance()

    func sendReferralBalanceRequest(with type: InputRewardAmountType, decimalBalance: Decimal)
}

protocol InputRewardAmountInteractorOutputProtocol: AnyObject {
    func received(_ balance: Decimal)
    func referralBalanceOperationReceived(with result: Result<String, Error>)
}

final class InputRewardAmountInteractor {
    weak var presenter: InputRewardAmountInteractorOutputProtocol?

    private var networkFacade: WalletNetworkOperationFactoryProtocol?
    private let operationFactory: ReferralsOperationFactoryProtocol
    private var feeAsset: AssetInfo

    init(networkFacade: WalletNetworkOperationFactoryProtocol,
         operationFactory: ReferralsOperationFactoryProtocol,
         feeAsset: AssetInfo) {
        self.networkFacade = networkFacade
        self.operationFactory = operationFactory
        self.feeAsset = feeAsset
    }
}

extension InputRewardAmountInteractor: InputRewardAmountInteractorInputProtocol {
    func getBalance() {
        if let operation = networkFacade?.fetchBalanceOperation([feeAsset.identifier]) {
            operation.targetOperation.completionBlock = { [weak self] in
                if let balance = try? operation.targetOperation.extractResultData(), let balance = balance?.first {
                    self?.presenter?.received(balance.balance.decimalValue)
                }
            }
            OperationManagerFacade.sharedManager.enqueue(operations: operation.allOperations, in: .transient)
        }
    }

    func sendReferralBalanceRequest(with type: InputRewardAmountType, decimalBalance: Decimal) {
        let balance = decimalBalance.toSubstrateAmount(precision: 18) ?? 0

        var operation = operationFactory.createExtrinsicReserveReferralBalanceOperation(with: balance)

        if type == .unbond {
            operation = operationFactory.createExtrinsicUnreserveReferralBalanceOperation(with: balance)
        }

        operation.completionBlock = { [weak self] in
            guard let result = operation.result else { return }
            self?.presenter?.referralBalanceOperationReceived(with: result)
        }

        OperationManagerFacade.sharedManager.enqueue(operations: [operation], in: .transient)
    }
}
