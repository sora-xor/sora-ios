import XCTest
@testable import SoraPassport
import SoraKeystore
import Cuckoo

class PhoneRegistrationTests: NetworkBaseTests {

    func testPhoneRegistrationSuccess() {
        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        UserCreationMock.register(mock: .success, projectUnit: projectUnit)

        let wireframe = MockPhoneRegistrationWireframeProtocol()

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).showPhoneVerification(from: any(), country: any()).then { _ in
                expectation.fulfill()
            }
        }

        let settings = InMemorySettingsManager()

        let presenter = createPresenter(settings: settings, country: createRandomCountry())
        presenter.wireframe = wireframe

        performPhoneRegistrationTest(for: presenter)

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)

        XCTAssertNotNil(settings.verificationState)
    }

    func testPhoneRegistrationAlreadyRegistered() {
        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        UserCreationMock.register(mock: .alreadyRegistered, projectUnit: projectUnit)

        let wireframe = MockPhoneRegistrationWireframeProtocol()

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).present(error: any(), from: any()).then { _ in
                expectation.fulfill()

                return true
            }
        }

        let settings = InMemorySettingsManager()

        let presenter = createPresenter(settings: settings, country: createRandomCountry())
        presenter.wireframe = wireframe

        performPhoneRegistrationTest(for: presenter)

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)

        XCTAssertNil(settings.verificationState)
    }

    func testPhoneRegistrationAlreadyVerified() {
        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        UserCreationMock.register(mock: .alreadyVerified, projectUnit: projectUnit)

        let wireframe = MockPhoneRegistrationWireframeProtocol()

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).present(error: any(), from: any()).thenReturn(true)
            when(stub).showRegistration(from: any(), country: any()).then { _ in
                expectation.fulfill()
            }
        }

        let settings = InMemorySettingsManager()

        let presenter = createPresenter(settings: settings, country: createRandomCountry())
        presenter.wireframe = wireframe

        performPhoneRegistrationTest(for: presenter)

        wait(for: [expectation], timeout: Constants.networkRequestTimeout)

        XCTAssertNil(settings.verificationState)
    }

    // MARK: Private

    private func performPhoneRegistrationTest(for presenter: PhoneRegistrationPresenter) {
        // given

        let view = MockPhoneRegistrationViewProtocol()
        presenter.view = view

        // when

        let input = createRandomPhoneInput()
        var phoneInputViewModel: PersonalInfoViewModelProtocol?

        stub(view) { stub in
            when(stub).didReceive(viewModel: any(PersonalInfoViewModelProtocol.self)).then { viewModel in
                let range = NSRange(location: viewModel.value.count, length: 0)
                _ = viewModel.didReceiveReplacement(input, for: range)
                phoneInputViewModel = viewModel
            }

            when(stub).didStartLoading().thenDoNothing()
            when(stub).didStopLoading().thenDoNothing()
        }

        // when

        presenter.setup()

        guard phoneInputViewModel?.value.hasSuffix(input) == true else {
            XCTFail("Unexpected phone number input")
            return
        }

        presenter.processPhoneInput()
    }

    private func createPresenter(settings: SettingsManagerProtocol, country: Country) -> PhoneRegistrationPresenter {
        let presenter = PhoneRegistrationPresenter(country: country)

        let projectService = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        projectService.requestSigner = createDummyRequestSigner()

        let interactor = PhoneRegistrationInteractor(accountService: projectService,
                                                     settings: settings)

        presenter.interactor = interactor
        interactor.presenter = presenter

        return presenter
    }
}
