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

    override func setUp() {
        super.setUp()

        try? Keychain().deleteAll()
        SettingsManager.shared.removeAll()

    }

    override func tearDown() {
        super.tearDown()

        try? Keychain().deleteAll()
        SettingsManager.shared.removeAll()
    }

    func testSuccessfullIdentityVerificationWhenPincodeNotSet() {
        performTestSuccessfullIdentityVerification(with: Keychain(), settings: SettingsManager.shared)
    }

    func testSuccessfullIdentityVerificationWhenPincodeSet() {
        let keychain = Keychain()
        try? keychain.saveKey(Constants.dummyPincode.data(using: .utf8)!, with: KeystoreKey.pincode.rawValue)
        performTestSuccessfullIdentityVerification(with: keychain, settings: SettingsManager.shared)
    }

    func testFailedIdentityVerificationWhenKeypairInvalid() {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit

        SupportedVersionCheckMock.register(mock: .supported, projectUnit: projectUnit)
        ProjectsCustomerMock.register(mock: .success, projectUnit: projectUnit)

        let document = createIdentity()

        let identityNetworkOperationFactory = MockDecentralizedResolverOperationFactoryProtocol()

        var settings = SettingsManager.shared
        let keychain = Keychain()

        let projectOperationFactory = ProjectOperationFactory()

        let interactor = StartupInteractor(settings: settings,
                                           keystore: keychain,
                                           config: ApplicationConfig.shared,
                                           identityNetworkOperationFactory: identityNetworkOperationFactory,
                                           identityLocalOperationFactory: IdentityOperationFactory.self,
                                           accountOperationFactory: projectOperationFactory,
                                           informationOperationFactory: projectOperationFactory,
                                           operationManager: OperationManager.shared,
                                           reachabilityManager: DummyReachabilityFactory.createMock())

        settings.decentralizedId = document.decentralizedId
        settings.publicKeyId = document.publicKey.first!.pubKeyId

        guard let newPrivateKey = IREd25519KeyFactory().createRandomKeypair() else {
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

        let identityRequestFactory = DecentralizedResolverOperationFactory(url: URL(string: ApplicationConfig.shared.didResolverUrl)!)

        let document = createIdentity()

        var settings = SettingsManager.shared
        settings.decentralizedId = document.decentralizedId
        settings.publicKeyId = document.publicKey.first!.pubKeyId

        let keychain = Keychain()

        guard let newPrivateKey = IREd25519KeyFactory().createRandomKeypair() else {
            XCTFail()
            return
        }

        XCTAssertNoThrow(try keychain.saveKey(newPrivateKey.privateKey().rawData(), with: KeystoreKey.privateKey.rawValue))

        let projectOperationFactory = ProjectOperationFactory()

        let interactor = StartupInteractor(settings: settings,
                                           keystore: keychain,
                                           config: ApplicationConfig.shared,
                                           identityNetworkOperationFactory: identityRequestFactory,
                                           identityLocalOperationFactory: IdentityOperationFactory.self,
                                           accountOperationFactory: projectOperationFactory,
                                           informationOperationFactory: projectOperationFactory,
                                           operationManager: OperationManager.shared,
                                           reachabilityManager: DummyReachabilityFactory.createMock())

        let wireframe = MockStartupWireframeProtocol()

        let presenter = StartupPresenter()
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
        presenter.viewIsReady()

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

        ProjectsCustomerMock.register(mock: .success, projectUnit: projectUnit)
        SupportedVersionCheckMock.register(mock: .supported, projectUnit: projectUnit)
        DecentralizedDocumentFetchMock.register(mock: .notFound)

        let document = createIdentity()

        let identityRequestFactory = DecentralizedResolverOperationFactory(url: URL(string: ApplicationConfig.shared.didResolverUrl)!)

        var settings = SettingsManager.shared
        let keychain = Keychain()

        let projectOperationFactory = ProjectOperationFactory()

        let interactor = StartupInteractor(settings: settings,
                                           keystore: keychain,
                                           config: ApplicationConfig.shared,
                                           identityNetworkOperationFactory: identityRequestFactory,
                                           identityLocalOperationFactory: IdentityOperationFactory.self,
                                           accountOperationFactory: projectOperationFactory,
                                           informationOperationFactory: projectOperationFactory,
                                           operationManager: OperationManager.shared,
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

        SupportedVersionCheckMock.register(mock: .supported, projectUnit: projectUnit)
        ProjectsCustomerMock.register(mock: .resourceNotFound, projectUnit: ApplicationConfig.shared.defaultProjectUnit)

        let document = createIdentity()

        let identityNetworkOperationFactory = MockDecentralizedResolverOperationFactoryProtocol()
        let projectOperationFactory = ProjectOperationFactory()

        var settings = SettingsManager.shared
        let keychain = Keychain()

        let interactor = StartupInteractor(settings: settings,
                                           keystore: keychain,
                                           config: ApplicationConfig.shared,
                                           identityNetworkOperationFactory: identityNetworkOperationFactory,
                                           identityLocalOperationFactory: IdentityOperationFactory.self,
                                           accountOperationFactory: projectOperationFactory,
                                           informationOperationFactory: projectOperationFactory,
                                           operationManager: OperationManager.shared,
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

    func performTestSuccessfullIdentityVerification(with keystore: KeystoreProtocol, settings: SettingsManagerProtocol) {
        // given

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit

        SupportedVersionCheckMock.register(mock: .supported, projectUnit: projectUnit)
        ProjectsCustomerMock.register(mock: .success, projectUnit: projectUnit)

        let document = createIdentity()

        let identityNetworkOperationFactory = MockDecentralizedResolverOperationFactoryProtocol()

        let projectOperationFactory = ProjectOperationFactory()

        let interactor = StartupInteractor(settings: settings,
                                           keystore: keystore,
                                           config: ApplicationConfig.shared,
                                           identityNetworkOperationFactory: identityNetworkOperationFactory,
                                           identityLocalOperationFactory: IdentityOperationFactory.self,
                                           accountOperationFactory: projectOperationFactory,
                                           informationOperationFactory: projectOperationFactory,
                                           operationManager: OperationManager.shared,
                                           reachabilityManager: DummyReachabilityFactory.createMock())

        var settingsManager = settings
        settingsManager.decentralizedId = document.decentralizedId
        settingsManager.publicKeyId = document.publicKey.first!.pubKeyId

        guard let pincodeExists = try? keystore.checkKey(for: KeystoreKey.pincode.rawValue) else {
            XCTFail()
            return
        }

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

        if (try? keystore.checkKey(for: KeystoreKey.privateKey.rawValue)) != true {
            XCTFail()
            return
        }

        guard (try? keystore.checkKey(for: KeystoreKey.pincode.rawValue)) == pincodeExists else {
            XCTFail()
            return
        }
    }
}
