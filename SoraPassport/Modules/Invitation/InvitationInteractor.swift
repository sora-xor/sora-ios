/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class InvitationInteractor {
    weak var presenter: InvitationInteractorOutputProtocol?

    private(set) var projectUnitService: ProjectUnitServiceProtocol
    private(set) var customerDataProviderFacade: CustomerDataProviderFacadeProtocol

    private var invitationCodeOperation: Operation?
    private var markOperation: Operation?

    deinit {
        invitationCodeOperation?.cancel()
    }

    init(service: ProjectUnitServiceProtocol,
         customerDataProviderFacade: CustomerDataProviderFacadeProtocol) {
        self.projectUnitService = service
        self.customerDataProviderFacade = customerDataProviderFacade
    }

    private func setupUserDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<UserData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let user):
                    self?.presenter?.didLoad(userValues: user.values)
                case .update(let user):
                    self?.presenter?.didLoad(userValues: user.values)
                case .delete:
                    break
                }
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveValuesDataProvider(error: error)
        }

        customerDataProviderFacade.userProvider.addCacheObserver(self,
                                                                 deliverOn: .main,
                                                                 executing: changesBlock,
                                                                 failing: failBlock)
    }

    private func setupInvitationsDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<ActivatedInvitationsData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let invitations):
                    self?.presenter?.didLoad(invitationsData: invitations)
                case .update(let invitations):
                    self?.presenter?.didLoad(invitationsData: invitations)
                case .delete:
                    break
                }
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveValuesDataProvider(error: error)
        }

        customerDataProviderFacade.friendsDataProvider.addCacheObserver(self,
                                                                        deliverOn: .main,
                                                                        executing: changesBlock,
                                                                        failing: failBlock)
    }

    private func process(result: OperationResult<InvitationCodeData>) {
        switch result {
        case .success(let code):
            presenter?.didLoad(invitationCodeData: code)
        case .error(let error):
            presenter?.didReceiveInvitationCode(error: error)
        }
    }

    private func processMark(result: OperationResult<Bool>, for invitationCode: String) {
        if case .success = result {
            presenter?.didMark(invitationCode: invitationCode)
        }
    }
}

extension InvitationInteractor: InvitationInteractorInputProtocol {
    func setup() {
        setupUserDataProvider()
        setupInvitationsDataProvider()
    }

    func refreshUserValues() {
        customerDataProviderFacade.userProvider.refreshCache()
    }

    func refreshInvitedUsers() {
        customerDataProviderFacade.friendsDataProvider.refreshCache()
    }

    func loadInvitationCode() {
        guard markOperation == nil else {
            presenter?.didReceiveInvitationCode(error: InvitationInteractorError.invalidatingPreviousCode)
            return
        }

        guard invitationCodeOperation == nil else {
            return
        }

        do {
            invitationCodeOperation = try projectUnitService
                .fetchInvitationCode(runCompletionIn: .main) { [weak self] (optionalResult) in
                self?.invitationCodeOperation = nil

                if let result = optionalResult {
                    self?.process(result: result)
                }
            }
        } catch {
            presenter?.didReceiveInvitationCode(error: error)
        }
    }

    func mark(invitationCode: String) {
        guard markOperation == nil else {
            return
        }

        markOperation = try? projectUnitService
            .markAsUsed(invitationCode: invitationCode, runCompletionIn: .main) { [weak self] (optionalResult) in
                self?.markOperation = nil

                if let result = optionalResult {
                    self?.processMark(result: result, for: invitationCode)
                }
        }
    }
}
