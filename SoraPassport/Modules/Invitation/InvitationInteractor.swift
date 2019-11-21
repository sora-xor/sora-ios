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
    private(set) var eventCenter: EventCenterProtocol

    private var invitationCodeOperation: Operation?
    private var markOperation: Operation?

    deinit {
        invitationCodeOperation?.cancel()
    }

    init(service: ProjectUnitServiceProtocol,
         customerDataProviderFacade: CustomerDataProviderFacadeProtocol,
         eventCenter: EventCenterProtocol) {
        self.projectUnitService = service
        self.customerDataProviderFacade = customerDataProviderFacade
        self.eventCenter = eventCenter
    }

    private func setupUserDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<UserData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let user):
                    self?.presenter?.didLoad(user: user)
                case .update(let user):
                    self?.presenter?.didLoad(user: user)
                case .delete:
                    break
                }
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveUserDataProvider(error: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                  waitsInProgressSyncOnAdd: false)

        customerDataProviderFacade.userProvider.addObserver(self,
                                                            deliverOn: .main,
                                                            executing: changesBlock,
                                                            failing: failBlock,
                                                            options: options)
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
            self?.presenter?.didReceiveInvitedUsersDataProvider(error: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                  waitsInProgressSyncOnAdd: false)

        customerDataProviderFacade.friendsDataProvider.addObserver(self,
                                                                   deliverOn: .main,
                                                                   executing: changesBlock,
                                                                   failing: failBlock,
                                                                   options: options)
    }

    private func process(result: Result<InvitationCodeData, Error>) {
        switch result {
        case .success(let code):
            presenter?.didLoad(invitationCodeData: code)
        case .failure(let error):
            presenter?.didReceiveInvitationCode(error: error)
        }
    }

    private func processMark(result: Result<Bool, Error>, for invitationCode: String) {
        if case .success = result {
            presenter?.didMark(invitationCode: invitationCode)
        }
    }
}

extension InvitationInteractor: InvitationInteractorInputProtocol {
    func setup() {
        setupUserDataProvider()
        setupInvitationsDataProvider()

        eventCenter.add(observer: self)
    }

    func refreshUser() {
        customerDataProviderFacade.userProvider.refresh()
    }

    func refreshInvitedUsers() {
        customerDataProviderFacade.friendsDataProvider.refresh()
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

    func apply(invitationCode: String) {
        eventCenter.notify(with: InvitationInputEvent(code: invitationCode))
    }
}

extension InvitationInteractor: EventVisitorProtocol {
    func processInvitationApplied(event: InvitationAppliedEvent) {
        refreshUser()
        refreshInvitedUsers()
    }
}
