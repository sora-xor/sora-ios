import XCTest
@testable import SoraPassport

class ProjectUnitReferendumServiceTests: NetworkBaseTests {
    var service: ProjectUnitService!

    override func setUp() {
        super.setUp()

        service = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        service.requestSigner = createDummyRequestSigner()
    }

    func testSupportVotingSuccess() {
        ReferendumSupportVoteMock.register(mock: .success,
                                           projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let customerVote = ReferendumVote(referendumId: Constants.dummyProjectId,
                                          votes: String(1),
                                          votingCase: .support)

        performVotingTest(customerVote)
    }

    func testUnsupportVotingSuccess() {
        ReferendumUnsupportVoteMock.register(mock: .success,
                                           projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let customerVote = ReferendumVote(referendumId: Constants.dummyProjectId,
                                          votes: String(1),
                                          votingCase: .unsupport)

        performVotingTest(customerVote)
    }

    func testReferendumDetailsFetchSuccess() {
        // given

        ReferendumDetailsFetchMock.register(mock: .success,
                                            projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when

        let operation = try? service.fetchReferendumDetails(for: Constants.dummyProjectId,
                                                            runCompletionIn: .main) { optionalResult in
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

    func testOpenReferendumsFetchSuccess() {
        // given

        ReferendumsOpenFetchMock.register(mock: .success,
                                          projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when

        let operation = try? service.fetchOpenReferendums(runCompletionIn: .main) { optionalResult in
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

    func testVotedReferendumsFetchSuccess() {
        // given

        ReferendumsVotedFetchMock.register(mock: .success,
                                           projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when

        let operation = try? service.fetchVotedReferendums(runCompletionIn: .main) { optionalResult in
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

    func testFinishedReferendumsFetchSuccess() {
        // given

        ReferendumsFinishedFetchMock.register(mock: .success,
                                              projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let expectation = XCTestExpectation()

        // when

        let operation = try? service.fetchFinishedReferendums(runCompletionIn: .main) { optionalResult in
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

    private func performVotingTest(_ vote: ReferendumVote) {
        // given

        let expectation = XCTestExpectation()

        // when

        let operation = try? service.vote(with: vote, runCompletionIn: .main) { (optionalResult) in
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
