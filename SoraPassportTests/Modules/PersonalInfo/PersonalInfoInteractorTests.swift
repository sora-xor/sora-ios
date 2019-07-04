/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import XCTest
@testable import SoraPassport
import Cuckoo
import SoraKeystore

class PersonalInfoInteractorTests: NetworkBaseTests {
    var interactor: PersonalInfoInteractor!

    override func setUp() {
        super.setUp()

        let identityUrl = URL(string: ApplicationConfig.shared.didResolverUrl)!
        let identityNetworkOperationFactory = DecentralizedResolverOperationFactory(url: identityUrl)
        interactor = PersonalInfoInteractor(projectOperationFactory: ProjectOperationFactory(),
                                            identityNetworkOperationFactory: identityNetworkOperationFactory,
                                            identityLocalOperationFactory: IdentityOperationFactory.self,
                                            settings: SettingsManager.shared,
                                            keystore: Keychain(),
                                            applicationConfig: ApplicationConfig.shared,
                                            operationManager: OperationManager.shared)
        clearStorage()
    }

    override func tearDown() {
        clearStorage()

        super.tearDown()
    }

    func testSuccessfullRegistration() {
        // given
        let applicationInfo = ApplicationFormInfo(applicationId: Constants.dummyApplicationFormId,
                                                  firstName: Constants.dummyFirstName,
                                                  lastName: Constants.dummyLastName,
                                                  phone: Constants.dummyPhone,
                                                  email: Constants.dummyEmail)

        ProjectsRegisterMock.register(mock: .success, projectUnit: ApplicationConfig.shared.defaultProjectUnit)
        DecentralizedDocumentCreateMock.register(mock: .success)

        let finishExpectation = XCTestExpectation()

        let presenterMock = MockPersonalInfoInteractorOutputProtocol()

        stub(presenterMock) { stub in
            when(stub.didStartRegistration(with: any(RegistrationInfo.self))).thenDoNothing()
            when(stub.didReceiveRegistration(error: any(Error.self))).thenDoNothing()
            when(stub.didCompleteRegistration(with: any(RegistrationInfo.self))).then { _ in
                finishExpectation.fulfill()
            }
        }

        // when
        XCTAssertTrue(!interactor.isBusy)

        interactor.presenter = presenterMock
        interactor.register(with: applicationInfo, invitationCode: Constants.dummyInvitationCode)

        // then
        XCTAssertTrue(interactor.isBusy)

        wait(for: [finishExpectation], timeout: Constants.networkRequestTimeout)

        XCTAssertTrue(!interactor.isBusy)

        verify(presenterMock, times(1)).didStartRegistration(with: any(RegistrationInfo.self))
        verify(presenterMock, times(1)).didCompleteRegistration(with: any(RegistrationInfo.self))
        verify(presenterMock, times(0)).didReceiveRegistration(error: any(Error.self))

        XCTAssertNotNil(interactor.settingsManager.decentralizedId)
        XCTAssertNotNil(interactor.settingsManager.publicKeyId)
        XCTAssertNotNil(interactor.settingsManager.verificationState)

        guard let keyExists = try? interactor.keystore.checkKey(for: KeystoreKey.privateKey.rawValue), keyExists else {
            XCTFail()
            return
        }

        guard let entropyExists = try? interactor.keystore.checkKey(for: KeystoreKey.seedEntropy.rawValue), entropyExists else {
            XCTFail()
            return
        }

        guard let pincodeExists = try? interactor.keystore.checkKey(for: KeystoreKey.pincode.rawValue), !pincodeExists else {
            XCTFail()
            return
        }
    }

    // MARK: Private

    private func clearStorage() {
        do {
            try interactor.keystore.deleteAll()
            interactor.settingsManager.removeAll()
        } catch {
            XCTFail("\(error)")
        }
    }
}
