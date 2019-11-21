/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class InvitationPresenter {
    private struct Constants {
        static let timerStyleSwitchThreshold: TimeInterval = 3600
    }

    enum InvitationActionType: Int {
        case sendInvite
        case enterCode
    }

    weak var view: InvitationViewProtocol?
    var interactor: InvitationInteractorInputProtocol!
    var wireframe: InvitationWireframeProtocol!

    let invitationViewModelFactory: InvitationViewModelFactoryProtocol
    let invitationFactory: InvitationFactoryProtocol
    let timerFactory: CountdownFactoryProtocol

    var logger: LoggerProtocol?

    var userData: UserData?
    var parentInfo: ParentInfoData?

    private(set) var layout: InvitationViewLayout = .default

    private(set) var timer: CountdownTimerProtocol?

    private var isSharingInvitation: Bool = false

    init(invitationViewModelFactory: InvitationViewModelFactoryProtocol,
         timerFactory: CountdownFactoryProtocol,
         invitationFactory: InvitationFactoryProtocol) {
        self.invitationViewModelFactory = invitationViewModelFactory
        self.timerFactory = timerFactory
        self.invitationFactory = invitationFactory
    }

    deinit {
        invalidateTimerIfNeeded()
    }

    private func invite(with code: String) {
        let invitationMessage = invitationFactory.createInvitation(from: code)
        let source = TextSharingSource(message: invitationMessage,
                                       subject: R.string.localizable.invitationsSharingSubject())

        wireframe.share(source: source, from: view) { [weak self] (completed) in
            self?.isSharingInvitation = false

            if completed {
                self?.interactor.mark(invitationCode: code)
            }
        }
    }

    private func updateInvitedUsers(from invitationsData: ActivatedInvitationsData) {
        let viewModels: [InvitedViewModel] = invitationViewModelFactory
            .createActivatedInvitationViewModel(from: invitationsData)

        view?.didReceive(invitedUsers: viewModels)
    }

    private func updateInvitationActions() {
        let viewModel = invitationViewModelFactory.createActionListViewModel(from: userData,
                                                                             parentInfo: parentInfo,
                                                                             layout: layout)

        view?.didReceive(actionListViewModel: viewModel)

        if let userData = userData {
            if userData.canAcceptInvitation {
                scheduleTimerIfNeeded()
                updateEnterCodeAccessory()
            } else {
                invalidateTimerIfNeeded()
            }
        }
    }

    private func updateEnterCodeAccessory() {
        if let timer = timer,
            let notificationType = TimerNotificationInterval(rawValue: timer.notificationInterval) {
            let accessoryTitle = invitationViewModelFactory
                .createActionAccessory(from: timer.remainedInterval,
                                       notificationInterval: notificationType)

            view?.didChange(accessoryTitle: accessoryTitle, at: InvitationActionType.enterCode.rawValue)

            let style: InvitationActionStyle = timer.remainedInterval > Constants.timerStyleSwitchThreshold
                ? .normal : .critical

            view?.didChange(actionStyle: style, at: InvitationActionType.enterCode.rawValue)
        }
    }

    private func scheduleTimerIfNeeded() {
        guard timer == nil else {
            return
        }

        if let remainedInterval = userData?.invitationExpirationInterval {
            let notificationType = remainedInterval <= Constants.timerStyleSwitchThreshold ?
                TimerNotificationInterval.second : TimerNotificationInterval.minute

            let timer = timerFactory.createTimer(with: self, notificationInterval: notificationType.rawValue)
            self.timer = timer

            timer.start(with: remainedInterval)
        }
    }

    private func invalidateTimerIfNeeded() {
        timer?.delegate = nil
        timer?.stop()
        timer = nil
    }

    private func sendInvitation() {
        if !isSharingInvitation {
            isSharingInvitation = true
            interactor.loadInvitationCode()
        }
    }

    private func enterInvitationCode() {
        let hint = R.string.localizable
            .inputFieldInvitationHintFormat(PersonalInfoSharedConstants.invitationCodeLimit)
        let title = R.string.localizable.inputFieldInvitationTitle()
        let inputFieldViewModel = LowecasedInputFieldViewModel(title: title,
                                                      hint: hint,
                                                      cancelActionTitle: R.string.localizable.cancel(),
                                                      doneActionTitle: R.string.localizable.apply())

        inputFieldViewModel.completionPredicate = NSPredicate.invitationCode
        inputFieldViewModel.invalidCharacters = NSCharacterSet.alphanumerics.inverted
        inputFieldViewModel.maximumLength = PersonalInfoSharedConstants.invitationCodeLimit
        inputFieldViewModel.delegate = self

        wireframe.requestInput(for: inputFieldViewModel, from: view)
    }
}

extension InvitationPresenter: InvitationPresenterProtocol {
    func viewIsReady(with layout: InvitationViewLayout) {
        self.layout = layout

        updateInvitationActions()

        interactor.setup()
    }

    func viewDidAppear() {
        interactor.refreshUser()
        interactor.refreshInvitedUsers()
    }

    func openHelp() {
        wireframe.presentHelp(from: view)
    }

    func didSelectAction(at index: Int) {
        guard let actionType = InvitationActionType(rawValue: index) else {
            return
        }

        switch actionType {
        case .sendInvite:
            sendInvitation()
        case .enterCode:
            enterInvitationCode()
        }
    }
}

extension InvitationPresenter: InvitationInteractorOutputProtocol {
    func didLoad(user: UserData) {
        userData = user

        updateInvitationActions()
    }

    func didReceiveUserDataProvider(error: Error) {
        logger?.debug("Did receive values data provider \(error)")
    }

    func didLoad(invitationsData: ActivatedInvitationsData) {
        parentInfo = invitationsData.parentInfo

        updateInvitedUsers(from: invitationsData)
        updateInvitationActions()
    }

    func didReceiveInvitedUsersDataProvider(error: Error) {
        logger?.debug("Did receive invited users data provider \(error)")
    }

    func didLoad(invitationCodeData: InvitationCodeData) {
        if isSharingInvitation {
            invite(with: invitationCodeData.invitationCode)
        }

        userData?.values.invitations = invitationCodeData.invitationsCount

        updateInvitationActions()
    }

    func didReceiveInvitationCode(error: Error) {
        isSharingInvitation = false

        if wireframe.present(error: error, from: view) {
            return
        }

        if let invitationCodeError = error as? InvitationCodeDataError {
            switch invitationCodeError {
            case .userValuesNotFound:
                wireframe.present(message: R.string.localizable.invitationsValuesNotFoundErrorMessage(),
                                  title: R.string.localizable.errorTitle(),
                                  closeAction: R.string.localizable.close(),
                                  from: view)
            case .notEnoughInvitations:
                wireframe.present(message: R.string.localizable.invitationsNotEnoughErrorMessage(),
                                  title: "",
                                  closeAction: R.string.localizable.close(),
                                  from: view)
            }
        }

        interactor.refreshUser()
    }

    func didMark(invitationCode: String) {
        interactor.refreshUser()
    }
}

extension InvitationPresenter: InputFieldViewModelDelegate {
    func inputFieldDidCancelInput(to viewModel: InputFieldViewModelProtocol) {
        logger?.debug("Did cancel invitation input")
    }

    func inputFieldDidCompleteInput(to viewModel: InputFieldViewModelProtocol) {
        interactor.apply(invitationCode: viewModel.value)
    }
}

extension InvitationPresenter: CountdownTimerDelegate {
    func didStart(with interval: TimeInterval) {
        logger?.debug("Did start invitation timer for \(interval)")
    }

    func didCountdown(remainedInterval: TimeInterval) {
        if remainedInterval <= Constants.timerStyleSwitchThreshold,
            timer?.notificationInterval != TimerNotificationInterval.second.rawValue {
            invalidateTimerIfNeeded()
            scheduleTimerIfNeeded()
        }

        updateEnterCodeAccessory()
    }

    func didStop(with remainedInterval: TimeInterval) {
        interactor.refreshUser()
        interactor.refreshInvitedUsers()

        updateInvitationActions()
    }
}
