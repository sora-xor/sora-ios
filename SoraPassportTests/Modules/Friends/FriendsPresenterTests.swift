import XCTest
import Cuckoo
@testable import SoraPassport

class FriendsPresenterTests: XCTestCase {

    func testTimerNotCreatedWhenParentExists() {
        // given

        let interactor = MockFriendsInteractorInputProtocol()

        let presenter = setup(interactor: interactor)

        var user = createRandomUser()
        user.parentId = createRandomUserId()

        var activatedInvitations = createRandomActivatedInvitationsData()
        activatedInvitations.parentInfo = createRandomParentInfo()

        // when

        presenter.setup()
        presenter.viewDidAppear()

        presenter.didLoad(user: user)
        presenter.didLoad(invitationsData: activatedInvitations)

        // then

        XCTAssertNil(presenter.timer)
    }

    func testTimerNotCreatedWhenParentMomentExpired() {
        // given

        let interactor = MockFriendsInteractorInputProtocol()

        let presenter = setup(interactor: interactor)

        var user = createRandomUser()
        user.inviteAcceptExpirationMoment = Int64(Date().timeIntervalSince1970 - 1.0)
        user.parentId = nil

        var activatedInvitations = createRandomActivatedInvitationsData()
        activatedInvitations.parentInfo = nil

        // when

        presenter.setup()
        presenter.viewDidAppear()

        presenter.didLoad(user: user)
        presenter.didLoad(invitationsData: activatedInvitations)

        // then

        XCTAssertNil(presenter.timer)
    }

//    func testPresenterUpdatesWhenTimerExpired() {
//        // given
//
//        let interactor = MockFriendsInteractorInputProtocol()
//
//        let presenter = setup(interactor: interactor)
//
//        let expirationOffset: TimeInterval = 1.0
//
//        var user = createRandomUser()
//        user.inviteAcceptExpirationMoment = Int64(Date().timeIntervalSince1970 + expirationOffset)
//        user.parentId = nil
//
//        var activatedInvitations = createRandomActivatedInvitationsData()
//        activatedInvitations.parentInfo = nil
//
//        // when
//
//        presenter.setup()
//        presenter.viewDidAppear()
//
//        let userRefreshExpection = XCTestExpectation()
//        let invitationsRefreshExpectation = XCTestExpectation()
//
//        stub(interactor) { stub in
//            when(stub).refreshUser().then {
//                userRefreshExpection.fulfill()
//            }
//
//            when(stub).refreshInvitedUsers().then {
//                invitationsRefreshExpectation.fulfill()
//            }
//        }
//
//        presenter.didLoad(user: user)
//        presenter.didLoad(invitationsData: activatedInvitations)
//
//        XCTAssertNotNil(presenter.timer)
//
//        // then
//
//        wait(for: [userRefreshExpection, invitationsRefreshExpectation],
//             timeout: Constants.networkRequestTimeout)
//
//        XCTAssertNil(presenter.timer)
//
//        // when
//
//        user.parentId = createRandomUserId()
//        activatedInvitations.parentInfo = createRandomParentInfo()
//
//        presenter.didLoad(user: user)
//        presenter.didLoad(invitationsData: activatedInvitations)
//
//        XCTAssertNil(presenter.timer)
//    }
}

// MARK: Private

private extension FriendsPresenterTests {

    func setup(
        view: MockFriendsViewProtocol = MockFriendsViewProtocol(),
        wireframe: MockFriendsWireframeProtocol = MockFriendsWireframeProtocol(),
        interactor: MockFriendsInteractorInputProtocol = MockFriendsInteractorInputProtocol()) -> FriendsPresenter {

        stub(view) { stub in
            when(stub).didReceive(rewardsViewModels: any()).thenDoNothing()
            when(stub).didReceive(friendsViewModel: any()).thenDoNothing()
            when(stub).didChange(applyInviteTitle: any()).thenDoNothing()
        }

        stub(interactor) { stub in
            when(stub).setup().thenDoNothing()
            when(stub).refreshUser().thenDoNothing()
            when(stub).refreshInvitedUsers().thenDoNothing()
        }

        return createPresenter(for: view, wireframe: wireframe, interactor: interactor)
    }

    func createPresenter(
        for view: MockFriendsViewProtocol,
        wireframe: MockFriendsWireframeProtocol,
        interactor: MockFriendsInteractorInputProtocol) -> FriendsPresenter {

        let timerFactory = CountdownTimerFactory()
        let friendsViewModelFactory = FriendsViewModelFactory()
        let rewardsViewModelFactory = RewardsViewModelFactory()

        let invitationFactory = InvitationFactory(
            host: ApplicationConfig.shared.invitationHostURL
        )

        let presenter = FriendsPresenter(
            timerFactory: timerFactory,
            invitationFactory: invitationFactory,
            friendsViewModelFactory: friendsViewModelFactory,
            rewardsViewModelFactory: rewardsViewModelFactory
        )

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        return presenter
    }
}
