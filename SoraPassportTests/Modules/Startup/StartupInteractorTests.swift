/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
import SoraCrypto
import IrohaCrypto
import SoraKeystore
import Cuckoo
import RobinHood
@testable import SoraPassport

class StartupInteractorTests: NetworkBaseTests {

    func testSuccessfullIdentityVerificationWhenPincodeNotSet() throws {
        try performTestSuccessfullIdentityVerification(with: InMemoryKeychain(),
                                                       settings: InMemorySettingsManager(),
                                                       clearSecondaryIdentities: false)
    }

    func testSuccessfullIdentityVerificationWhenPincodeSet() throws {
        let keychain = InMemoryKeychain()
        try keychain.saveKey(Constants.dummyPincode.data(using: .utf8)!, with: KeystoreKey.pincode.rawValue)
        try performTestSuccessfullIdentityVerification(with: keychain,
                                                       settings: InMemorySettingsManager(),
                                                       clearSecondaryIdentities: false)
    }

    func testSuccessullSecondaryIdentitiesCreationOnStart() throws {
        try performTestSuccessfullIdentityVerification(with: InMemoryKeychain(),
                                                       settings: InMemorySettingsManager(),
                                                       clearSecondaryIdentities: true)
    }

    func testFailedIdentityVerificationWhenKeypairInvalid() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit

        EthConfigMock.register(mock: .available, projectUnit: projectUnit)
        SupportedVersionCheckMock.register(mock: .supported, projectUnit: projectUnit)
        ProjectsCustomerMock.register(mock: .successWithParent, projectUnit: projectUnit)

        let identityNetworkOperationFactory = MockDecentralizedResolverOperationFactoryProtocol()

        var settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        let document = createIdentity(with: keychain)

        let projectOperationFactory = ProjectOperationFactory()

        let interactor = StartupInteractor(settings: settings,
                                           keystore: keychain,
                                           config: ApplicationConfig.shared,
                                           identityNetworkOperationFactory: identityNetworkOperationFactory,
                                           identityLocalOperationFactory: IdentityOperationFactory(),
                                           accountOperationFactory: projectOperationFactory,
                                           informationOperationFactory: projectOperationFactory,
                                           operationManager: OperationManagerFacade.sharedManager,
                                           reachabilityManager: DummyReachabilityFactory.createMock())

        settings.decentralizedId = document.decentralizedId
        settings.publicKeyId = document.publicKey.first!.pubKeyId

        guard let newPrivateKey = try? IRIrohaKeyFactory().createRandomKeypair() else {
            XCTFail()
            return
        }

        XCTAssertNoThrow(try keychain.saveKey(newPrivateKey.privateKey().rawData(), with: KeystoreKey.privateKey.rawValue))

        stub(identityNetworkOperationFactory) { stub in
            when(stub).createDecentralizedDocumentFetchOperation(decentralizedId: any(String.self)).then { _ in
                let requestFactory = BlockNetworkRequestFactory {
                    return URLRequest(url: URL(string: ApplicationConfig.shared.didResolverUrl)!)
                }

                let responseFactory = AnyNetworkResultFactory<DecentralizedDocumentObject> { (data) in
                    return document
                }

                let networkOperation = NetworkOperation<DecentralizedDocumentObject>(requestFactory: requestFactory,
                                                                                     resultFactory: responseFactory)
                networkOperation.result = .success(document)

                return networkOperation
            }
        }

        let presenter = MockStartupInteractorOutputProtocol()
        interactor.presenter = presenter

        let expectation = XCTestExpectation()

        stub(presenter) { stub in
            when(stub.didDecideOnboarding()).then {
                expectation.fulfill()
            }

            when(stub).didChangeState().thenDoNothing()
        }

        // when
        interactor.verify()

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then
        XCTAssertTrue(interactor.state == .completed)
        XCTAssertNil(interactor.settings.decentralizedId)
        XCTAssertNil(interactor.settings.publicKeyId)

        if (try? keychain.checkKey(for: KeystoreKey.privateKey.rawValue)) != false {
            XCTFail()
        }
    }

    func testUnsupportedVersion() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        SupportedVersionCheckMock.register(mock: .unsupported, projectUnit: projectUnit)
        EthConfigMock.register(mock: .available, projectUnit: projectUnit)

        let identityRequestFactory = DecentralizedResolverOperationFactory(url: URL(string: ApplicationConfig.shared.didResolverUrl)!)

        let keychain = InMemoryKeychain()

        let document = createIdentity(with: keychain)

        var settings = InMemorySettingsManager()
        settings.decentralizedId = document.decentralizedId
        settings.publicKeyId = document.publicKey.first!.pubKeyId

        guard let newPrivateKey = try? IRIrohaKeyFactory().createRandomKeypair() else {
            XCTFail()
            return
        }

        XCTAssertNoThrow(try keychain.saveKey(newPrivateKey.privateKey().rawData(), with: KeystoreKey.privateKey.rawValue))

        let projectOperationFactory = ProjectOperationFactory()

        let interactor = StartupInteractor(settings: settings,
                                           keystore: keychain,
                                           config: ApplicationConfig.shared,
                                           identityNetworkOperationFactory: identityRequestFactory,
                                           identityLocalOperationFactory: IdentityOperationFactory(),
                                           accountOperationFactory: projectOperationFactory,
                                           informationOperationFactory: projectOperationFactory,
                                           operationManager: OperationManagerFacade.sharedManager,
                                           reachabilityManager: DummyReachabilityFactory.createMock())

        let wireframe = MockStartupWireframeProtocol()

        let presenter = StartupPresenter(locale: Locale.current)
        presenter.interactor = interactor
        presenter.wireframe = wireframe

        interactor.presenter = presenter

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in

            when(stub).presentUnsupportedVersion(for: any(), on: any(), animated: any()).then { _ in
                expectation.fulfill()
            }

        }

        // when
        presenter.setup()
        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then
        XCTAssertTrue(interactor.state == .unsupported)
        XCTAssertNotNil(interactor.settings.decentralizedId)
        XCTAssertNotNil(interactor.settings.publicKeyId)

        if (try? keychain.checkKey(for: KeystoreKey.privateKey.rawValue)) == false {
            XCTFail()
        }
    }

    func testFailedIdentityVerificationWhenDIDNotFound() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit

        EthConfigMock.register(mock: .available, projectUnit: projectUnit)
        ProjectsCustomerMock.register(mock: .successWithParent, projectUnit: projectUnit)
        SupportedVersionCheckMock.register(mock: .supported, projectUnit: projectUnit)
        DecentralizedDocumentFetchMock.register(mock: .notFound)

        var settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        let document = createIdentity(with: keychain)

        let identityRequestFactory = DecentralizedResolverOperationFactory(url: URL(string: ApplicationConfig.shared.didResolverUrl)!)

        let projectOperationFactory = ProjectOperationFactory()

        let interactor = StartupInteractor(settings: settings,
                                           keystore: keychain,
                                           config: ApplicationConfig.shared,
                                           identityNetworkOperationFactory: identityRequestFactory,
                                           identityLocalOperationFactory: IdentityOperationFactory(),
                                           accountOperationFactory: projectOperationFactory,
                                           informationOperationFactory: projectOperationFactory,
                                           operationManager: OperationManagerFacade.sharedManager,
                                           reachabilityManager: DummyReachabilityFactory.createMock())

        settings.decentralizedId = document.decentralizedId
        settings.publicKeyId = document.publicKey.first!.pubKeyId

        let presenter = MockStartupInteractorOutputProtocol()
        interactor.presenter = presenter

        let expectation = XCTestExpectation()

        stub(presenter) { stub in
            when(stub.didDecideOnboarding()).then {
                expectation.fulfill()
            }

            when(stub).didChangeState().thenDoNothing()
        }

        // when
        interactor.verify()

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then
        XCTAssertTrue(interactor.state == .completed)
        XCTAssertNil(interactor.settings.decentralizedId)
        XCTAssertNil(interactor.settings.publicKeyId)

        if (try? keychain.checkKey(for: KeystoreKey.privateKey.rawValue)) != false {
            XCTFail()
        }
    }

    func testRetryIdentityVerification() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit

        EthConfigMock.register(mock: .available, projectUnit: projectUnit)
        SupportedVersionCheckMock.register(mock: .supported, projectUnit: projectUnit)
        ProjectsCustomerMock.register(mock: .resourceNotFound, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        var settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        let document = createIdentity(with: keychain)

        let identityNetworkOperationFactory = MockDecentralizedResolverOperationFactoryProtocol()
        let projectOperationFactory = ProjectOperationFactory()

        let interactor = StartupInteractor(settings: settings,
                                           keystore: keychain,
                                           config: ApplicationConfig.shared,
                                           identityNetworkOperationFactory: identityNetworkOperationFactory,
                                           identityLocalOperationFactory: IdentityOperationFactory(),
                                           accountOperationFactory: projectOperationFactory,
                                           informationOperationFactory: projectOperationFactory,
                                           operationManager: OperationManagerFacade.sharedManager,
                                           reachabilityManager: DummyReachabilityFactory.createMock(returnIsReachable: false))

        settings.decentralizedId = document.decentralizedId
        settings.publicKeyId = document.publicKey.first!.pubKeyId

        stub(identityNetworkOperationFactory) { stub in
            when(stub).createDecentralizedDocumentFetchOperation(decentralizedId: any(String.self)).then { _ in
                let requestFactory = BlockNetworkRequestFactory {
                    return URLRequest(url: URL(string: ApplicationConfig.shared.didResolverUrl)!)
                }

                let responseFactory = AnyNetworkResultFactory<DecentralizedDocumentObject> { (data) in
                    return document
                }

                let networkOperation = NetworkOperation<DecentralizedDocumentObject>(requestFactory: requestFactory,
                                                                                     resultFactory: responseFactory)
                networkOperation.result = .success(document)

                return networkOperation
            }
        }

        let presenter = MockStartupInteractorOutputProtocol()
        interactor.presenter = presenter

        stub(presenter) { stub in
            when(stub.didDecideOnboarding()).thenDoNothing()
            when(stub.didDecidePincodeSetup()).thenDoNothing()
            when(stub.didDecideMain()).thenDoNothing()
            when(stub.didChangeState()).thenDoNothing()
        }

        let expectation = XCTestExpectation()

        DispatchQueue(label: UUID().uuidString).async {
            while interactor.state != .waitingRetry {}
            expectation.fulfill()
        }

        // when
        interactor.verify()

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then
        XCTAssertEqual(interactor.settings.decentralizedId, document.decentralizedId)
        XCTAssertTrue(document.publicKey.contains(where: { $0.pubKeyId == interactor.settings.publicKeyId }))

        if (try? keychain.checkKey(for: KeystoreKey.privateKey.rawValue)) != true {
            XCTFail()
        }
    }

    // MARK: Private

    func performTestSuccessfullIdentityVerification(with keystore: KeystoreProtocol,
                                                    settings: SettingsManagerProtocol,
                                                    clearSecondaryIdentities: Bool) throws {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit

        EthConfigMock.register(mock: .available, projectUnit: projectUnit)
        SupportedVersionCheckMock.register(mock: .supported, projectUnit: projectUnit)
        ProjectsCustomerMock.register(mock: .successWithParent, projectUnit: projectUnit)

        let document = createIdentity(with: keystore)

        let secondaryIdentityRepository = SecondaryIdentityRepository(keystore: keystore)

        var initialSecondaryKeys: [Data] = []

        if clearSecondaryIdentities {
            try secondaryIdentityRepository.clear()
        } else {
            initialSecondaryKeys = try secondaryIdentityRepository.fetchAll()
        }

        let identityNetworkOperationFactory = MockDecentralizedResolverOperationFactoryProtocol()

        let projectOperationFactory = ProjectOperationFactory()

        let interactor = StartupInteractor(settings: settings,
                                           keystore: keystore,
                                           config: ApplicationConfig.shared,
                                           identityNetworkOperationFactory: identityNetworkOperationFactory,
                                           identityLocalOperationFactory: IdentityOperationFactory(),
                                           accountOperationFactory: projectOperationFactory,
                                           informationOperationFactory: projectOperationFactory,
                                           operationManager: OperationManagerFacade.sharedManager,
                                           reachabilityManager: DummyReachabilityFactory.createMock())

        var settingsManager = settings
        settingsManager.decentralizedId = document.decentralizedId
        settingsManager.publicKeyId = document.publicKey.first!.pubKeyId

        let pincodeExists = try keystore.checkKey(for: KeystoreKey.pincode.rawValue)

        stub(identityNetworkOperationFactory) { stub in
            when(stub).createDecentralizedDocumentFetchOperation(decentralizedId: document.decentralizedId).then { _ in
                let requestFactory = BlockNetworkRequestFactory {
                    return URLRequest(url: URL(string: ApplicationConfig.shared.didResolverUrl)!)
                }

                let responseFactory = AnyNetworkResultFactory<DecentralizedDocumentObject> { (data) in
                    return document
                }

                let networkOperation = NetworkOperation<DecentralizedDocumentObject>(requestFactory: requestFactory,
                                                                                     resultFactory: responseFactory)
                networkOperation.result = .success(document)

                return networkOperation
            }
        }

        let presenter = MockStartupInteractorOutputProtocol()
        interactor.presenter = presenter

        let expectation = XCTestExpectation()

        stub(presenter) { stub in
            if !pincodeExists {
                when(stub.didDecidePincodeSetup()).then {
                    expectation.fulfill()
                }
            } else {
                when(stub.didDecideMain()).then {
                    expectation.fulfill()
                }
            }

            when(stub).didChangeState().thenDoNothing()
        }

        // when
        interactor.verify()

        wait(for: [expectation], timeout: Constants.expectationDuration)

        // then
        XCTAssertTrue(interactor.state == .completed)
        XCTAssertEqual(interactor.settings.decentralizedId, document.decentralizedId)
        XCTAssertTrue(document.publicKey.contains(where: { $0.pubKeyId == interactor.settings.publicKeyId }))

        XCTAssertTrue(try keystore.checkKey(for: KeystoreKey.privateKey.rawValue))

        if clearSecondaryIdentities {
            XCTAssertTrue(try secondaryIdentityRepository.checkAllExist())
        } else {
            XCTAssertEqual(try secondaryIdentityRepository.fetchAll(),
                           initialSecondaryKeys)
        }

        XCTAssertEqual(try keystore.checkKey(for: KeystoreKey.pincode.rawValue),
                       pincodeExists)
    }
}
