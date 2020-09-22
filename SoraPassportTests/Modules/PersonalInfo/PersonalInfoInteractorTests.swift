/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport
import Cuckoo
import SoraKeystore
import SoraFoundation

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
            let viewModelFactory = PersonalInfoViewModelFactory()
            let presenter = PersonalInfoPresenter(viewModelFactory: viewModelFactory,
                                                  personalForm: form,
                                                  locale: Locale.current)
            let interactor = createInteractor(for: settings, keystore: keystore)

            presenter.view = view
            presenter.wireframe = wireframe
            presenter.interactor = interactor

            interactor.presenter = presenter

            let setupExpectation = XCTestExpectation()

            let footerExpectation = XCTestExpectation()

            var currentViewModels: [InputViewModelProtocol]?

            stub(view) { stub in
                when(stub).didReceive(viewModels: any([InputViewModelProtocol].self)).then { viewModels in
                    currentViewModels = viewModels

                    setupExpectation.fulfill()
                }

                when(stub).didReceive(footerViewModel: any()).then { _ in
                    footerExpectation.fulfill()
                }
            }

            // when

            presenter.load()

            // then

            wait(for: [setupExpectation, footerExpectation], timeout: Constants.networkRequestTimeout)

            // when

            _ = currentViewModels?[PersonalInfoPresenter.ViewModelIndex.firstName.rawValue].inputHandler
                .didReceiveReplacement(Constants.dummyFirstName, for: NSRange(location: 0, length: 0))
            _ = currentViewModels?[PersonalInfoPresenter.ViewModelIndex.lastName.rawValue].inputHandler
                .didReceiveReplacement(Constants.dummyLastName, for: NSRange(location: 0, length: 0))

            let invitationDeliveredExpectation = XCTestExpectation()

            stub(view) { stub in
                when(stub).didReceive(viewModels: any([InputViewModelProtocol].self)).then { viewModels in
                    XCTAssertEqual(viewModels[PersonalInfoPresenter.ViewModelIndex.firstName.rawValue].inputHandler.value,
                                   Constants.dummyFirstName)

                    XCTAssertEqual(viewModels[PersonalInfoPresenter.ViewModelIndex.lastName.rawValue].inputHandler.value,
                                   Constants.dummyLastName)
                    XCTAssertEqual(viewModels[PersonalInfoPresenter.ViewModelIndex.invitationCode.rawValue].inputHandler.value,
                                   Constants.dummyInvitationCode)

                    invitationDeliveredExpectation.fulfill()
                }

                when(stub).didReceive(footerViewModel: any()).thenDoNothing()
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

        let locale = Locale.current
        let viewModelFactory = PersonalInfoViewModelFactory()
        let presenter = PersonalInfoPresenter(viewModelFactory: viewModelFactory,
                                              personalForm: form,
                                              locale: locale)
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
            when(stub).didReceive(viewModels: any([InputViewModelProtocol].self)).then { viewModels in
                _ = viewModels[PersonalInfoPresenter.ViewModelIndex.firstName.rawValue].inputHandler
                    .didReceiveReplacement(Constants.dummyFirstName, for: NSRange(location: 0, length: 0))
                _ = viewModels[PersonalInfoPresenter.ViewModelIndex.lastName.rawValue].inputHandler
                    .didReceiveReplacement(Constants.dummyLastName, for: NSRange(location: 0, length: 0))
                _ = viewModels[PersonalInfoPresenter.ViewModelIndex.invitationCode.rawValue].inputHandler
                    .didReceiveReplacement(Constants.dummyInvitationCode, for: NSRange(location: 0, length: 0))
            }

            when(stub).didReceive(footerViewModel: any()).thenDoNothing()
        }

        // when

        presenter.load()

        presenter.register()

        // then

        wait(for: [finishExpectation], timeout: Constants.networkRequestTimeout)

        // no footer should be displayed when there is an invitation code

        if settings.invitationCode != nil {
            verify(view, times(0)).didReceive(footerViewModel: any())
        }
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
