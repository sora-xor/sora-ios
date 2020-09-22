import Foundation
import RobinHood

protocol SoranetUnitOperationFactoryProtocol: class {
    func withdrawProofOperation(_ urlTemplate: String, info: WithdrawProofInfo) -> NetworkOperation<WithdrawProofData?>
}
