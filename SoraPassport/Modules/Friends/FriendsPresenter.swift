import Foundation
import SoraKeystore
import SoraFoundation
import SoraUI

extension FriendsPresenter {

    enum InvitationActionType: Int {
        case copyInviteCode
        case sendInvite
        case enterCode
    }

    private struct Constants {
        static let timerStyleSwitchThreshold: TimeInterval = 3600
    }
}

final class FriendsPresenter {
    weak var view: FriendsViewProtocol?
    var wireframe: FriendsWireframeProtocol!
    var interactor: FriendsInteractorInputProtocol!

    let timerFactory: CountdownFactoryProtocol
    let invitationFactory: InvitationFactoryProtocol
    let friendsViewModelFactory: FriendsViewModelFactoryProtocol
    let rewardsViewModelFactory: RewardsViewModelFactoryProtocol

    var logger: LoggerProtocol?

    private(set) var userData: UserData?
    private(set) var parentInfo: ParentInfoData?

    private(set) var timer: CountdownTimerProtocol?

    private var isSharingInvitation: Bool = false

    init(timerFactory: CountdownFactoryProtocol,
         invitationFactory: InvitationFactoryProtocol,
         friendsViewModelFactory: FriendsViewModelFactoryProtocol,
         rewardsViewModelFactory: RewardsViewModelFactoryProtocol) {
        self.timerFactory = timerFactory
        self.invitationFactory = invitationFactory
        self.friendsViewModelFactory = friendsViewModelFactory
        self.rewardsViewModelFactory = rewardsViewModelFactory
    }

    deinit {
        invalidateTimer()
    }
}

// MARK: - Private Functions

private extension FriendsPresenter {

    func updateInvitedUsers(from invitationsData: ActivatedInvitationsData) {
        let viewModels = rewardsViewModelFactory
            .createActivatedInvitationViewModel(
                from: invitationsData,
                dateFormatter: DateFormatter.friends,
                locale: locale
            )

        view?.didReceive(rewardsViewModels: viewModels)
    }

    func updateInvitationActions() {
        let viewModel = friendsViewModelFactory
            .createActionListViewModel(from: userData)

        view?.didReceive(friendsViewModel: viewModel)

        if let userData = userData {
            if userData.canAcceptInvitation {
                scheduleTimer()
                updateInviteCodeTitle()
            } else {
                invalidateTimer()
            }
        }
    }

    func updateInviteCodeTitle() {
        if let timer = timer,
           let notificationType = TimerNotificationInterval(rawValue: timer.notificationInterval) {
            let timerValue = friendsViewModelFactory.createActionAccessory(
                for: languages, from: timer.remainedInterval, notificationInterval: notificationType
            )

            let inviteTitle = R.string.localizable.inviteCodeApply(preferredLanguages: languages)

            view?.didChange(applyInviteTitle: "\(inviteTitle) (\(timerValue))")
        }
    }

    func scheduleTimer() {
        guard timer == nil else {
            return
        }

        if let remainedInterval = userData?.invitationExpirationInterval {
            let notificationType = remainedInterval <= Constants.timerStyleSwitchThreshold ?
                TimerNotificationInterval.second : TimerNotificationInterval.minute

            timer = timerFactory.createTimer(with: self, notificationInterval: notificationType.rawValue)

            timer?.start(with: remainedInterval)
        }
    }

    func invalidateTimer() {
        timer?.delegate = nil
        timer?.stop()
        timer = nil
    }

    func copyInviteCodeAction() {
        guard !isSharingInvitation else { return }

        guard let invitationCode = userData?.values.invitationCode else {
            present(
                message: R.string.localizable.inviteCodeWasntCopied(preferredLanguages: languages),
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                closeAction: R.string.localizable.commonClose(preferredLanguages: languages), from: view
            )
            return
        }

        UIPasteboard.general.string = invitationCode

        isSharingInvitation = true

        let closeTitle = R.string.localizable.commonClose(preferredLanguages: languages)
        let closeAction = AlertPresentableAction(title: closeTitle) { [weak self] in
            self?.isSharingInvitation = false
        }

    }

    func sendInvitationAction() {
        if !isSharingInvitation {
            isSharingInvitation = true

            let invitationCode = ""

            let invitationMessage = invitationFactory.createInvitation(
                from: invitationCode, locale: locale
            )

            let subject = R.string.localizable
                .invitationsSharingSubject(preferredLanguages: languages)

            let source = TextSharingSource(
                message: invitationMessage, subject: subject
            )

            wireframe.share(source: source, from: view) { [weak self] _ in
                self?.isSharingInvitation = false
            }
        }
    }

    func enterInvitationCodeAction() {
        let inputFieldViewModel = InputFieldViewModel(
            title: R.string.localizable.inviteEnterInvitationCode(preferredLanguages: languages),
            hint: R.string.localizable.inviteEnterDialogHintTemplate(preferredLanguages: languages),
            cancelActionTitle: R.string.localizable.commonCancel(preferredLanguages: languages),
            doneActionTitle: R.string.localizable.commonApply(preferredLanguages: languages)
        )

        inputFieldViewModel.completionPredicate = NSPredicate.invitationCode
        inputFieldViewModel.invalidCharacters = NSCharacterSet.alphanumerics.inverted
        inputFieldViewModel.maximumLength = PersonalInfoSharedConstants.invitationCodeLimit
        inputFieldViewModel.delegate = self

        wireframe.requestInput(for: inputFieldViewModel, from: view)
    }
}

// MARK: - Presenter Protocol

extension FriendsPresenter: FriendsPresenterProtocol {

    func setup() {
        updateInvitationActions()
        interactor.setup()
    }

    func viewDidAppear() {
        interactor.refreshUser()
        interactor.refreshInvitedUsers()
    }

    func didSelectAction(_ action: FriendsPresenter.InvitationActionType) {
        switch action {
        case .copyInviteCode:   copyInviteCodeAction()
        case .sendInvite:       sendInvitationAction()
        case .enterCode:        enterInvitationCodeAction()
        }
    }
}

// MARK: - Interactor Output Protocol

extension FriendsPresenter: FriendsInteractorOutputProtocol {

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
}

// MARK: - InputField Delegate

extension FriendsPresenter: InputFieldViewModelDelegate {

    func inputFieldDidCancelInput(to viewModel: InputFieldViewModelProtocol) {
        logger?.debug("Did cancel invitation input")
    }

    func inputFieldDidCompleteInput(to viewModel: InputFieldViewModelProtocol) {
        interactor.apply(invitationCode: viewModel.value)
    }
}

// MARK: - CountdownTimer Delegate

extension FriendsPresenter: CountdownTimerDelegate {

    func didStart(with interval: TimeInterval) {
        logger?.debug("Did start invitation timer for \(interval)")
    }

    func didCountdown(remainedInterval: TimeInterval) {
        if remainedInterval <= Constants.timerStyleSwitchThreshold,
           timer?.notificationInterval != TimerNotificationInterval.second.rawValue {
            invalidateTimer()
            scheduleTimer()
        }

        updateInviteCodeTitle()
    }

    func didStop(with remainedInterval: TimeInterval) {
        interactor.refreshUser()
        interactor.refreshInvitedUsers()

        updateInvitationActions()
    }
}

// MARK: - Localizable

extension FriendsPresenter: Localizable {

    var locale: Locale {
        return localizationManager?.selectedLocale ?? Locale.current
    }

    var languages: [String] {
        return localizationManager?.preferredLocalizations ?? []
    }

    func applyLocalization() {
        if view?.isSetup == true {
            updateInvitationActions()
        }
    }
}
