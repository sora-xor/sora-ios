/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport
import Cuckoo

class InvitationPresenterTests: XCTestCase {
    func testTimerNotCreatedWhenParentExists() {
        // given

        let interactor = MockInvitationInteractorInputProtocol()

        let presenter = setup(interactor: interactor)

        var user = createRandomUser()
        user.parentId = createRandomUserId()

        var activatedInvitations = createRandomActivatedInvitationsData()
        activatedInvitations.parentInfo = createRandomParentInfo()

        // when

        presenter.viewIsReady(with: .default)
        presenter.viewDidAppear()

        presenter.didLoad(user: user)
        presenter.didLoad(invitationsData: activatedInvitations)

        // then

        XCTAssertNil(presenter.timer)
    }

    func testTimerNotCreatedWhenParentMomentExpired() {
        // given

        let interactor = MockInvitationInteractorInputProtocol()

        let presenter = setup(interactor: interactor)

        var user = createRandomUser()
        user.inviteAcceptExpirationMoment = Int64(Date().timeIntervalSince1970 - 1.0)
        user.parentId = nil

        var activatedInvitations = createRandomActivatedInvitationsData()
        activatedInvitations.parentInfo = nil

        // when

        presenter.viewIsReady(with: .default)
        presenter.viewDidAppear()

        presenter.didLoad(user: user)
        presenter.didLoad(invitationsData: activatedInvitations)

        // then

        XCTAssertNil(presenter.timer)
    }

    func testPresenterUpdatesWhenTimerExpired() {
        // given

        let interactor = MockInvitationInteractorInputProtocol()

        let presenter = setup(interactor: interactor)

        let expirationOffset: TimeInterval = 1.0

        var user = createRandomUser()
        user.inviteAcceptExpirationMoment = Int64(Date().timeIntervalSince1970 + expirationOffset)
        user.parentId = nil

        var activatedInvitations = createRandomActivatedInvitationsData()
        activatedInvitations.parentInfo = nil

        // when

        presenter.viewIsReady(with: .default)
        presenter.viewDidAppear()

        let userRefreshExpection = XCTestExpectation()
        let invitationsRefreshExpectation = XCTestExpectation()

        stub(interactor) { stub in
            when(stub).refreshUser().then {
                userRefreshExpection.fulfill()
            }

            when(stub).refreshInvitedUsers().then {
                invitationsRefreshExpectation.fulfill()
            }
        }

        presenter.didLoad(user: user)
        presenter.didLoad(invitationsData: activatedInvitations)

        XCTAssertNotNil(presenter.timer)

        // then

        wait(for: [userRefreshExpection, invitationsRefreshExpectation],
             timeout: Constants.networkRequestTimeout)

        XCTAssertNil(presenter.timer)

        // when

        user.parentId = createRandomUserId()
        activatedInvitations.parentInfo = createRandomParentInfo()

        presenter.didLoad(user: user)
        presenter.didLoad(invitationsData: activatedInvitations)

        XCTAssertNil(presenter.timer)
    }

    // MARK: Private

    private func setup(view: MockInvitationViewProtocol = MockInvitationViewProtocol(),
                       wireframe: MockInvitationWireframeProtocol = MockInvitationWireframeProtocol(),
                       interactor: MockInvitationInteractorInputProtocol = MockInvitationInteractorInputProtocol())
        -> InvitationPresenter {
        stub(view) { stub in
            when(stub).didReceive(actionListViewModel: any()).thenDoNothing()
            when(stub).didReceive(invitedUsers: any()).thenDoNothing()
            when(stub).didChange(accessoryTitle: any(), at: any()).thenDoNothing()
            when(stub).didChange(actionStyle: any(), at: any()).thenDoNothing()
        }

        stub(interactor) { stub in
            when(stub).setup().thenDoNothing()
            when(stub).refreshUser().thenDoNothing()
            when(stub).refreshInvitedUsers().thenDoNothing()
        }

        return createPresenter(for: view, wireframe: wireframe, interactor: interactor)
    }

    private func createPresenter(for view: MockInvitationViewProtocol, wireframe: MockInvitationWireframeProtocol, interactor: MockInvitationInteractorInputProtocol)
        -> InvitationPresenter {

        let invitationFactory = InvitationFactory(host: ApplicationConfig.shared.invitationHostURL)

        let invitationViewModelFactory = InvitationViewModelFactory(integerFormatter: NumberFormatter.anyInteger)
        let timerFactory = CountdownTimerFactory()

        let presenter = InvitationPresenter(invitationViewModelFactory: invitationViewModelFactory,
                                            timerFactory: timerFactory,
                                            invitationFactory: invitationFactory)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        return presenter
    }
}
