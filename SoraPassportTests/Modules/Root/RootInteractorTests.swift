import XCTest
import Cuckoo
@testable import SoraPassport
import SoraKeystore

class RootInteractorTests: XCTestCase {
    var view: UIWindow!
    var presenter: RootPresenter!
    var interactor: RootInteractor!
    var wireframe: MockRootWireframeProtocol!

    private(set) var keystore =  InMemoryKeychain()
    private(set) var settings = InMemorySettingsManager()

    override func setUp() {
        try? keystore.deleteAll()
        settings.removeAll()

        defaultSetup()
    }

    override func tearDown() {
        try? keystore.deleteAll()
        settings.removeAll()
    }

    func testDecidedOnboardingWhenNoDecentralizedId() {
        performTestDecidedOnboarding()
    }


    private func performTestDecidedOnboarding() {
        // given
        let viewMatcher = ParameterMatcher<UIWindow> { $0 === self.view }

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.showOnboarding(on: viewMatcher)).then { view in
                expectation.fulfill()
            }
        }

        // when
        presenter.loadOnLaunch()

        // then
        wait(for: [expectation], timeout: Constants.expectationDuration)
    }

    func testDecideLocalAuth() {
        // given
        let viewMatcher = ParameterMatcher<UIWindow> { $0 === self.view }

        try? AccountCreationHelper.createAccountFromMnemonic(
                                                            cryptoType: .sr25519,
                                                            networkType: .sora,
                                                            keychain: keystore,
                                                            settings: settings)

        settings.decentralizedId = Constants.dummyDid
        settings.publicKeyId = Constants.dummyPubKeyId

        try? keystore.saveKey(Constants.dummyPincode.data(using: .utf8)!, with: KeystoreTag.pincode.rawValue)

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.showLocalAuthentication(on: viewMatcher)).then { view in
                expectation.fulfill()
            }
        }

        // when
        presenter.loadOnLaunch()

        // then
        wait(for: [expectation], timeout: Constants.expectationDuration)

        XCTAssertEqual(settings.decentralizedId, Constants.dummyDid)
    }

    // MARK: Private

    private func defaultSetup() {
        view = UIWindow()
        presenter = RootPresenter()
        wireframe = MockRootWireframeProtocol()
        let securityLayerInteractor = MockSecurityLayerInteractorInputProtocol()
        let networkAvailabilityLayer = MockNetworkAvailabilityLayerInteractorInputProtocol()

        stub(securityLayerInteractor) { stub in
            when(stub).setup().thenDoNothing()
        }

        stub(networkAvailabilityLayer) { stub in
            when(stub).setup().thenDoNothing()
        }

        interactor = RootInteractor(settings: settings,
                                    keystore: keystore,
                                    migrators: [],
                                    securityLayerInteractor: securityLayerInteractor,
                                    networkAvailabilityLayerInteractor: networkAvailabilityLayer)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter
    }
}
