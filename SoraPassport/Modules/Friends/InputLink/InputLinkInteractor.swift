/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import IrohaCrypto

protocol InputLinkInteractorInputProtocol: AnyObject {
    func sendSetReferrerRequest(with referrerAddress: String)
    func isCurrentUserAddress(with address: String) -> Bool
    func getAccountId(from address: String) -> Data?
}

protocol InputLinkInteractorOutputProtocol: AnyObject {
    func setReferralRequestReceived(withSuccess isSuccess: Bool)
}

final class InputLinkInteractor {
    weak var presenter: InputLinkInteractorOutputProtocol?

    private let operationManager: OperationManager
    private let operationFactory: ReferralsOperationFactoryProtocol
    private let addressFactory: SS58AddressFactory
    private let selectedAccountAddress: String

    init(operationManager: OperationManager,
         operationFactory: ReferralsOperationFactoryProtocol,
         addressFactory: SS58AddressFactory,
         selectedAccountAddress: String) {
        self.operationManager = operationManager
        self.operationFactory = operationFactory
        self.addressFactory = addressFactory
        self.selectedAccountAddress = selectedAccountAddress
    }
}

extension InputLinkInteractor: InputLinkInteractorInputProtocol {
    func sendSetReferrerRequest(with referrerAddress: String) {

        let operation = operationFactory.createExtrinsicSetReferrerOperation(with: referrerAddress)

        operation.completionBlock = { [weak self] in
            guard case .success = operation.result else {
                self?.presenter?.setReferralRequestReceived(withSuccess: false)
                return
            }
            self?.presenter?.setReferralRequestReceived(withSuccess: true)
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func getAccountId(from address: String) -> Data? {
        guard let addressType = try? addressFactory.extractAddressType(from: address),
              let accountId = try? addressFactory.accountId(fromAddress: address, type: addressType) else {
            return nil
        }

        return accountId
    }

    func isCurrentUserAddress(with address: String) -> Bool {
        return selectedAccountAddress == address
    }
}
