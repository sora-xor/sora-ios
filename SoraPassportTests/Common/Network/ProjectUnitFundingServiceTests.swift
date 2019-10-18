/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport

class ProjectUnitFundingServiceTests: NetworkBaseTests {
    var service: ProjectUnitService!

    override func setUp() {
        super.setUp()

        service = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        service.requestSigner = createDummyRequestSigner()
    }

    func testFetchProjectsSuccess() {
        // given
        ProjectsFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.fetchAllProjects(with: Pagination(offset: 0, count: 10), runCompletionIn: .main) { (optionalResult) in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult else {
                XCTFail()
                return
            }

            guard case .success = result else {
                XCTFail()
                return
            }
        }

        guard operation != nil else {
            XCTFail()
            return
        }

        // then
        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testFetchFavoriteProjectsSuccess() {
        // given
        ProjectsFavoritesFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.fetchFavoriteProjects(with: Pagination(offset: 0, count: 10), runCompletionIn: .main) { (optionalResult) in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult else {
                XCTFail()
                return
            }

            guard case .success = result else {
                XCTFail()
                return
            }
        }

        guard operation != nil else {
            XCTFail()
            return
        }

        // then
        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testFetchVotedProjectsSuccess() {
        // given
        ProjectsVotedFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.fetchVotedProjects(with: Pagination(offset: 0, count: 10), runCompletionIn: .main) { (optionalResult) in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult else {
                XCTFail()
                return
            }

            guard case .success = result else {
                XCTFail()
                return
            }
        }

        guard operation != nil else {
            XCTFail()
            return
        }

        // then
        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testFetchFinishedProjectsSuccess() {
        // given
        ProjectsFinishedFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.fetchFinishedProjects(with: Pagination(offset: 0, count: 10), runCompletionIn: .main) { (optionalResult) in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult else {
                XCTFail()
                return
            }

            guard case .success = result else {
                XCTFail()
                return
            }
        }

        guard operation != nil else {
            XCTFail()
            return
        }

        // then
        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testFetchProjectDetailsSuccess() {
        // given
        ProjectDetailsFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.fetchProjectDetails(for: Constants.dummyProjectId, runCompletionIn: .main) { (optionalResult) in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult else {
                XCTFail()
                return
            }

            guard case .success = result else {
                XCTFail()
                return
            }
        }

        if operation == nil {
            XCTFail()
            return
        }

        // then
        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testToggleFavoriteProjectSuccess() {
        // given
        ProjectsToggleFavoriteMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.toggleFavorite(projectId: Constants.dummyProjectId, runCompletionIn: .main) { (optionalResult) in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult, case .success = result else {
                XCTFail()
                return
            }
        }

        guard operation != nil else {
            XCTFail()
            return
        }

        // then
        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testVoteForProjectSuccess() {
        // given
        ProjectsVoteMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let customerVote = ProjectVote(projectId: Constants.dummyProjectId, votes: String(0))
        let operation = try? service.vote(with: customerVote, runCompletionIn: .main) { (optionalResult) in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult, case .success = result else {
                XCTFail()
                return
            }
        }

        guard operation != nil else {
            XCTFail()
            return
        }

        // then
        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testVotesFetchSuccess() {
        // given
        ProjectsVotesCountMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let operation = try? service.fetchVotes(runCompletionIn: .main) { (optionalResult) in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult, case .success = result else {
                XCTFail()
                return
            }
        }

        guard operation != nil else {
            XCTFail()
            return
        }

        // then
        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }

    func testVotesHistoryFetchSuccess() {
        // given
        VotesHistoryFetchMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when
        let votesHistoryInfo = Pagination(offset: 0, count: 50)
        let operation = try? service.fetchVotesHistory(with: votesHistoryInfo, runCompletionIn: .main) { (optionalResult) in
            defer {
                expectation.fulfill()
            }

            guard let result = optionalResult, case .success = result else {
                XCTFail()
                return
            }
        }

        guard operation != nil else {
            XCTFail()
            return
        }

        // then
        wait(for: [expectation], timeout: Constants.networkRequestTimeout)
    }
}
