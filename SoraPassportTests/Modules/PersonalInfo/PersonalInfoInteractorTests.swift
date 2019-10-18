/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport
import Cuckoo
import SoraKeystore

class PersonalInfoInteractorTests: NetworkBaseTests {

    func testSuccessfullRegistration() {
        do {
            let keystore = InMemoryKeychain()
            var settings = InMemorySettingsManager()

            try keystore.saveKey(Data(), with: KeystoreKey.privateKey.rawValue)
            try keystore.saveKey(Data(), with: KeystoreKey.seedEntropy.rawValue)
            settings.verificationState = VerificationState()
            settings.decentralizedId = Constants.dummyDid
            settings.invitationCode = Constants.dummyInvitationCode

            performTestSuccessfullRegistration(for: createRandomCountry(with: true), settings: settings, keystore: keystore)

            XCTAssertNotNil(settings.decentralizedId)
            XCTAssertNil(settings.verificationState)
            XCTAssertNil(settings.invitationCode)

            guard let keyExists = try? keystore.checkKey(for: KeystoreKey.privateKey.rawValue), keyExists else {
                XCTFail("Private key must be preserved")
                return
            }

            guard let entropyExists = try? keystore.checkKey(for: KeystoreKey.seedEntropy.rawValue), entropyExists else {
                XCTFail("Entropy must be preservedr")
                return
            }

            guard let pincodeExists = try? keystore.checkKey(for: KeystoreKey.pincode.rawValue), !pincodeExists else {
                XCTFail("Pincode must be unset")
                return
            }

        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testInvitationLinkDelivered() {
        do {
            // given

            let keystore = InMemoryKeychain()
            var settings = InMemorySettingsManager()

            try keystore.saveKey(Data(), with: KeystoreKey.privateKey.rawValue)
            try keystore.saveKey(Data(), with: KeystoreKey.seedEntropy.rawValue)
            settings.verificationState = VerificationState()
            settings.decentralizedId = Constants.dummyDid

            let projectUnit = ApplicationConfig.shared.defaultProjectUnit
            ProjectsRegisterMock.register(mock: .success, projectUnit: projectUnit)

            let view = MockPersonalInfoViewProtocol()
            let wireframe = MockPersonalInfoWireframeProtocol()

            let form = PersonalForm.create(from: createRandomCountry())
            let presenter = PersonalInfoPresenter(viewModelFactory: PersonalInfoViewModelFactory(), personalForm: form)
            let interactor = createInteractor(for: settings, keystore: keystore)

            presenter.view = view
            presenter.wireframe = wireframe
            presenter.interactor = interactor

            interactor.presenter = presenter

            let setupExpectation = XCTestExpectation()

            stub(view) { stub in
                when(stub).didReceive(viewModels: any([PersonalInfoViewModelProtocol].self)).then { viewModels in
                    _ = viewModels[PersonalInfoPresenter.ViewModelIndex.firstName.rawValue]
                        .didReceiveReplacement(Constants.dummyFirstName, for: NSRange(location: 0, length: 0))
                    _ = viewModels[PersonalInfoPresenter.ViewModelIndex.lastName.rawValue]
                        .didReceiveReplacement(Constants.dummyLastName, for: NSRange(location: 0, length: 0))

                    setupExpectation.fulfill()
                }
            }

            // when

            presenter.load()

            // then

            wait(for: [setupExpectation], timeout: Constants.networkRequestTimeout)

            // when

            let invitationDeliveredExpectation = XCTestExpectation()

            stub(view) { stub in
                when(stub).didReceive(viewModels: any([PersonalInfoViewModelProtocol].self)).then { viewModels in
                    XCTAssertEqual(viewModels[PersonalInfoPresenter.ViewModelIndex.firstName.rawValue].value, Constants.dummyFirstName)
                    XCTAssertEqual(viewModels[PersonalInfoPresenter.ViewModelIndex.lastName.rawValue].value, Constants.dummyLastName)
                    XCTAssertEqual(viewModels[PersonalInfoPresenter.ViewModelIndex.invitationCode.rawValue].value, Constants.dummyInvitationCode)

                    invitationDeliveredExpectation.fulfill()
                }
            }

            XCTAssertTrue(interactor.invitationLinkService.handle(url: Constants.dummyInvitationLink))

            wait(for: [invitationDeliveredExpectation], timeout: Constants.networkRequestTimeout)

        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    // MARK: Private

    func performTestSuccessfullRegistration(for country: Country, settings: SettingsManagerProtocol, keystore: KeystoreProtocol) {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        ProjectsRegisterMock.register(mock: .success, projectUnit: projectUnit)

        let view = MockPersonalInfoViewProtocol()
        let wireframe = MockPersonalInfoWireframeProtocol()

        let form = PersonalForm.create(from: country)
        let presenter = PersonalInfoPresenter(viewModelFactory: PersonalInfoViewModelFactory(), personalForm: form)
        let interactor = createInteractor(for: settings, keystore: keystore)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        let finishExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).showPassphraseBackup(from: any()).then { _ in
                finishExpectation.fulfill()
            }
        }

        stub(view) { stub in
            when(stub).didStartLoading().thenDoNothing()
            when(stub).didStopLoading().thenDoNothing()
            when(stub).didReceive(viewModels: any([PersonalInfoViewModelProtocol].self)).then { viewModels in
                _ = viewModels[PersonalInfoPresenter.ViewModelIndex.firstName.rawValue]
                    .didReceiveReplacement(Constants.dummyFirstName, for: NSRange(location: 0, length: 0))
                _ = viewModels[PersonalInfoPresenter.ViewModelIndex.lastName.rawValue]
                    .didReceiveReplacement(Constants.dummyLastName, for: NSRange(location: 0, length: 0))
                _ = viewModels[PersonalInfoPresenter.ViewModelIndex.invitationCode.rawValue]
                    .didReceiveReplacement(Constants.dummyInvitationCode, for: NSRange(location: 0, length: 0))
            }
        }

        // when

        presenter.load()

        presenter.register()

        // then

        wait(for: [finishExpectation], timeout: Constants.networkRequestTimeout)
    }

    private func createInteractor(for settings: SettingsManagerProtocol, keystore: KeystoreProtocol) -> PersonalInfoInteractor {
        let projectService = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        projectService.requestSigner = createDummyRequestSigner()

        return PersonalInfoInteractor(registrationService: projectService,
                                      settings: settings,
                                      keystore: keystore,
                                      invitationLinkService: InvitationLinkService(settings: settings))
    }
}
