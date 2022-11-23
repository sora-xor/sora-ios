import XCTest
@testable import SoraPassport
import SoraFoundation
import SoraKeystore
import RobinHood

class OnboardingServiceTests: NetworkBaseTests {
/*
    func testOnboardingPreparationWhenInvitationChecked() {
        do {
            // given

            let applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared

            SupportedVersionCheckMock.register(mock: .supported, projectUnit: applicationConfig.defaultProjectUnit)

            let invitationLinkService = MockInvitationLinkServiceProtocol()
            var settings = InMemorySettingsManager()
            let keychain = InMemoryKeychain()

            let projectFactory = ProjectOperationFactory()

            let onboardingPreparationService = OnboardingPreparationService(
                accountOperationFactory: projectFactory,
                informationOperationFactory: projectFactory,
                invitationLinkService: invitationLinkService,
                deviceInfoFactory: DeviceInfoFactory(),
                keystore: keychain,
                settings: settings,
                applicationConfig: applicationConfig)

            settings.isCheckedInvitation = true

            // when

            let operationQueue = OperationQueue()
            let operationManager = OperationManager(operationQueue: operationQueue)

            let operation = try onboardingPreparationService.prepare(using: operationManager)

            // then

            let operations = operationQueue.operations

            XCTAssertEqual(operations.count, 2)

            let expectation = XCTestExpectation()

            operation.completionBlock = {
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: Constants.expectationDuration)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
*/
}
