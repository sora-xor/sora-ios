/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import RobinHood

final class InvitationInputInteractor {
    weak var presenter: InvitationInputInteractorOutputProtocol?

    private(set) var projectService: ProjectUnitServiceProtocol

    private var checkOperation: Operation?

    init(projectService: ProjectUnitServiceProtocol) {
        self.projectService = projectService
    }

    deinit {
        checkOperation?.cancel()
        checkOperation = nil
    }

    private func process(result: OperationResult<ApplicationFormData?>, code: String) {
        switch result {
        case .success(let applicationForm):
            presenter?.didSuccessfullProcess(code: code, received: applicationForm)
        case .error(let error):
            presenter?.didReceiveProcessing(error: error, for: code)
        }
    }
}

extension InvitationInputInteractor: InvitationInputInteractorProtocol {
    var isProcessing: Bool {
        return checkOperation != nil
    }

    func process(code: String) {
        checkOperation?.cancel()
        checkOperation = nil

        presenter?.didStartProcessing(code: code)
        do {
            checkOperation = try projectService
                .checkInvitation(code: code, runCompletionIn: .main) { [weak self] (optionalResult) in
                if let result = optionalResult {
                    self?.checkOperation = nil
                    self?.process(result: result, code: code)
                }
            }
        } catch {
            presenter?.didReceiveProcessing(error: error, for: code)
        }
    }
}
